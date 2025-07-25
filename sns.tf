# =============================================================================
# SNS Configuration for Alert Notifications
# =============================================================================

# SNS Topic for monitoring alerts
resource "aws_sns_topic" "monitoring_alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
  
  # Enable server-side encryption
  kms_master_key_id = "alias/aws/sns"

  # Delivery policy for better reliability
  delivery_policy = jsonencode({
    "http" = {
      "defaultHealthyRetryPolicy" = {
        "minDelayTarget"     = 20,
        "maxDelayTarget"     = 20,
        "numRetries"         = 3,
        "numMaxDelayRetries" = 0,
        "numMinDelayRetries" = 0,
        "numNoDelayRetries"  = 0,
        "backoffFunction"    = "linear"
      },
      "disableSubscriptionOverrides" = false
    }
  })

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-alerts"
    Component   = "Alerting"
    Description = "SNS topic for serverless API monitoring alerts"
  })
}

# Primary email subscription
resource "aws_sns_topic_subscription" "primary_email_alerts" {
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email

  # Automatically confirm subscription (useful for automation)
  confirmation_timeout_in_minutes = 5
}

# Additional email subscriptions
resource "aws_sns_topic_subscription" "additional_email_alerts" {
  count     = length(var.additional_alert_emails)
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = var.additional_alert_emails[count.index]

  confirmation_timeout_in_minutes = 5
}

# SNS Topic Policy for cross-account access (if needed)
resource "aws_sns_topic_policy" "monitoring_alerts_policy" {
  arn = aws_sns_topic.monitoring_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${var.project_name}-sns-policy"
    Statement = [
      {
        Sid    = "AllowCloudWatchAlarmsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.monitoring_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowLambdaToPublish"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.monitoring_alerts.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# CloudWatch Log Group for SNS delivery failures
resource "aws_cloudwatch_log_group" "sns_delivery_logs" {
  name              = "/aws/sns/${var.project_name}-${var.environment}-delivery-failures"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-sns-logs"
    Component = "Logging"
  })
}