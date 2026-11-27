variable "aws_region" {
  default = "us-east-1"
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL"
  sensitive   = true
}

variable "audit_bucket_name" {
  description = "Globally unique S3 bucket name for audit logs"
}

variable "dry_run" {
  description = "If true, remediate.py only logs what it would do"
  default     = "false"
}
