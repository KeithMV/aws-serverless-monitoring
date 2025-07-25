# =============================================================================
# Security Monitoring Lambda Function
# =============================================================================

# Lambda function for automated security monitoring
resource "aws_lambda_function" "security_monitor" {
  count            = var.enable_security_monitoring ? 1 : 0
  filename         = data.archive_file.security_monitor_zip[0].output_path
  function_name    = "${var.project_name}-${var.environment}-security-monitor"
  role            = aws_iam_role.security_monitor_role[0].arn
  handler         = "security_monitor.lambda_handler"
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 256

  source_code_hash = data.archive_file.security_monitor_zip[0].output_base64sha256

  environment {
    variables = {
      SNS_TOPIC_ARN           = aws_sns_topic.monitoring_alerts.arn
      API_NAME                = var.monitored_api_name
      SECURITY_ERROR_THRESHOLD = var.security_error_threshold
      PROJECT_NAME            = var.project_name
      ENVIRONMENT             = var.environment
    }
  }

  # Enable dead letter queue for failed invocations
  dead_letter_config {
    target_arn = aws_sqs_queue.security_monitor_dlq[0].arn
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-security-monitor"
    Component = "Security-Monitoring"
    Runtime   = "python3.11"
  })
}

# Dead Letter Queue for failed Lambda invocations
resource "aws_sqs_queue" "security_monitor_dlq" {
  count                     = var.enable_security_monitoring ? 1 : 0
  name                      = "${var.project_name}-${var.environment}-security-monitor-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-security-monitor-dlq"
    Component = "Security-Monitoring"
  })
}

# CloudWatch Log Group for Security Monitor Lambda
resource "aws_cloudwatch_log_group" "security_monitor_logs" {
  count             = var.enable_security_monitoring ? 1 : 0
  name              = "/aws/lambda/${var.project_name}-${var.environment}-security-monitor"
  retention_in_days = 14

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-security-monitor-logs"
    Component = "Security-Monitoring"
  })
}

# Lambda deployment package
data "archive_file" "security_monitor_zip" {
  count       = var.enable_security_monitoring ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/security_monitor.zip"
  source {
    content = templatefile("${path.module}/lambda/security_monitor.py", {
      project_name = var.project_name
      environment  = var.environment
    })
    filename = "security_monitor.py"
  }
}

# =============================================================================
# IAM Configuration for Security Monitor
# =============================================================================

resource "aws_iam_role" "security_monitor_role" {
  count = var.enable_security_monitoring ? 1 : 0
  name  = "${var.project_name}-${var.environment}-security-monitor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-security-monitor-role"
    Component = "Security-Monitoring"
  })
}

resource "aws_iam_role_policy" "security_monitor_policy" {
  count = var.enable_security_monitoring ? 1 : 0
  name  = "${var.project_name}-${var.environment}-security-monitor-policy"
  role  = aws_iam_role.security_monitor_role[0].id

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
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-security-monitor",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-security-monitor:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.monitoring_alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.security_monitor_dlq[0].arn
      }
    ]
  })
}

# =============================================================================
# EventBridge Scheduling
# =============================================================================

resource "aws_cloudwatch_event_rule" "security_monitor_schedule" {
  count               = var.enable_security_monitoring ? 1 : 0
  name                = "${var.project_name}-${var.environment}-security-monitor-schedule"
  description         = "Trigger security monitoring Lambda on schedule"
  schedule_expression = var.monitoring_schedule

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-security-monitor-schedule"
    Component = "Security-Monitoring"
  })
}

resource "aws_cloudwatch_event_target" "security_monitor_target" {
  count     = var.enable_security_monitoring ? 1 : 0
  rule      = aws_cloudwatch_event_rule.security_monitor_schedule[0].name
  target_id = "SecurityMonitorTarget"
  arn       = aws_lambda_function.security_monitor[0].arn

  # Retry configuration
  retry_policy {
    maximum_retry_attempts       = 3
    maximum_event_age_in_seconds = 3600
  }

  # Dead letter configuration
  dead_letter_config {
    arn = aws_sqs_queue.security_monitor_dlq[0].arn
  }
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_security_monitoring ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_monitor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_monitor_schedule[0].arn
}

# =============================================================================
# Security Monitor Alarms
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "security_monitor_errors" {
  count               = var.enable_security_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-security-monitor-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when security monitoring Lambda function has errors"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.security_monitor[0].function_name
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-security-monitor-errors"
    Component = "Security-Monitoring"
    Severity  = "High"
  })
}