output "slack_callback_url" {
  description = "Paste this into Slack App → Interactivity → Request URL"
  value       = "${aws_apigatewayv2_api.slack_callback.api_endpoint}/slack"
}

output "audit_bucket" {
  value = aws_s3_bucket.audit.id
}

output "notify_lambda" {
  value = aws_lambda_function.notify.function_name
}

output "remediate_lambda" {
  value = aws_lambda_function.remediate.function_name
}
