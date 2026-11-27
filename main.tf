terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------- Audit bucket ----------
resource "aws_s3_bucket" "audit" {
  bucket = var.audit_bucket_name
}

resource "aws_s3_bucket_public_access_block" "audit" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- Lambda packaging ----------
data "archive_file" "notify" {
  type        = "zip"
  source_file = "${path.module}/lambda/notify.py"
  output_path = "${path.module}/build/notify.zip"
}

data "archive_file" "remediate" {
  type        = "zip"
  source_file = "${path.module}/lambda/remediate.py"
  output_path = "${path.module}/build/remediate.zip"
}

# ---------- IAM role for both Lambdas ----------
resource "aws_iam_role" "lambda_role" {
  name = "cspm-remediation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "cspm-remediation-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
            {
        Effect   = "Allow"
        Action   = ["s3:PutBucketPublicAccessBlock", "s3:GetBucketPublicAccessBlock"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.audit.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["securityhub:GetFindings", "securityhub:UpdateFindings"]
        Resource = "*"
      }
    ]
  })
}

# ---------- notify Lambda ----------
resource "aws_lambda_function" "notify" {
  function_name    = "cspm-notify"
  role             = aws_iam_role.lambda_role.arn
  handler          = "notify.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.notify.output_path
  source_code_hash = data.archive_file.notify.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
}

# ---------- remediate Lambda ----------
resource "aws_lambda_function" "remediate" {
  function_name    = "cspm-remediate"
  role             = aws_iam_role.lambda_role.arn
  handler          = "remediate.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.remediate.output_path
  source_code_hash = data.archive_file.remediate.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      AUDIT_BUCKET = aws_s3_bucket.audit.id
      DRY_RUN      = var.dry_run
    }
  }
}

# ---------- EventBridge rule: Security Hub HIGH/CRITICAL ----------
resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name        = "cspm-securityhub-findings"
  description = "Trigger notify Lambda on HIGH/CRITICAL Security Hub findings"

event_pattern = jsonencode({
    source      = ["aws.securityhub", "custom.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["HIGH", "CRITICAL"]
        }
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "notify_target" {
  rule      = aws_cloudwatch_event_rule.securityhub_findings.name
  target_id = "notify-lambda"
  arn       = aws_lambda_function.notify.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.securityhub_findings.arn
}

# ---------- API Gateway for Slack button callbacks ----------
resource "aws_apigatewayv2_api" "slack_callback" {
  name          = "cspm-slack-callback"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.slack_callback.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "remediate" {
  api_id                 = aws_apigatewayv2_api.slack_callback.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.remediate.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "slack_post" {
  api_id    = aws_apigatewayv2_api.slack_callback.id
  route_key = "POST /slack"
  target    = "integrations/${aws_apigatewayv2_integration.remediate.id}"
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediate.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.slack_callback.execution_arn}/*/*"
}