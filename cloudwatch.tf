# =============================================================================
# CloudWatch Alarms and Monitoring Configuration
# =============================================================================

# =============================================================================
# API Gateway Monitoring Alarms
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = var.metric_period_seconds
  statistic           = "Sum"
  threshold           = var.api_error_threshold
  alarm_description   = "Alert when API Gateway 4XX errors exceed ${var.api_error_threshold} in ${var.alarm_evaluation_periods} periods"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.monitored_api_name
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-api-4xx-errors"
    Component = "API-Monitoring"
    Severity  = "High"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = var.metric_period_seconds
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when API Gateway 5XX errors occur"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.monitored_api_name
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-api-5xx-errors"
    Component = "API-Monitoring"
    Severity  = "Critical"
  })
}

resource "aws_cloudwatch_metric_alarm" "api_high_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-api-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = var.metric_period_seconds
  statistic           = "Average"
  threshold           = "5000"  # 5 seconds
  alarm_description   = "Alert when API Gateway latency exceeds 5 seconds"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = var.monitored_api_name
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-api-latency"
    Component = "API-Monitoring"
    Severity  = "Medium"
  })
}

# =============================================================================
# Lambda Function Monitoring Alarms
# =============================================================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = length(var.monitored_lambda_functions)
  alarm_name          = "${var.project_name}-${var.environment}-${var.monitored_lambda_functions[count.index]}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = var.metric_period_seconds
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when Lambda function ${var.monitored_lambda_functions[count.index]} has errors"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.monitored_lambda_functions[count.index]
  }

  tags = merge(var.tags, {
    Name         = "${var.project_name}-${var.environment}-${var.monitored_lambda_functions[count.index]}-errors"
    Component    = "Lambda-Monitoring"
    Severity     = "High"
    FunctionName = var.monitored_lambda_functions[count.index]
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count               = length(var.monitored_lambda_functions)
  alarm_name          = "${var.project_name}-${var.environment}-${var.monitored_lambda_functions[count.index]}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = var.metric_period_seconds
  statistic           = "Average"
  threshold           = var.lambda_duration_threshold_ms
  alarm_description   = "Alert when Lambda function ${var.monitored_lambda_functions[count.index]} duration exceeds ${var.lambda_duration_threshold_ms}ms"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.monitored_lambda_functions[count.index]
  }

  tags = merge(var.tags, {
    Name         = "${var.project_name}-${var.environment}-${var.monitored_lambda_functions[count.index]}-duration"
    Component    = "Lambda-Monitoring"
    Severity     = "Medium"
    FunctionName = var.monitored_lambda_functions[count.index]
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  count               = length(var.monitored_lambda_functions)
  alarm_name          = "${var.project_name}-${var.environment}-${var.monitored_lambda_functions[count.index]}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = var.metric_period_seconds
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alert when Lambda function ${var.monitored_lambda_functions[count.index]} is throttled"
  alarm_actions       = [aws_sns_topic.monitoring_alerts.arn]
  ok_actions          = [aws_sns_topic.monitoring_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.monitored_lambda_functions[count.index]
  }

  tags = merge(var.tags, {
    Name         = "${var.project_name}-${var.environment}-${var.monitored_lambda_functions[count.index]}-throttles"
    Component    = "Lambda-Monitoring"
    Severity     = "High"
    FunctionName = var.monitored_lambda_functions[count.index]
  })
}

# =============================================================================
# CloudWatch Dashboard
# =============================================================================

resource "aws_cloudwatch_dashboard" "api_monitoring" {
  count          = var.enable_dashboard ? 1 : 0
  dashboard_name = "${var.project_name}-${var.environment}-monitoring"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.monitored_api_name, { "stat": "Sum" }],
            [".", "4XXError", ".", ".", { "stat": "Sum" }],
            [".", "5XXError", ".", ".", { "stat": "Sum" }],
            [".", "Latency", ".", ".", { "stat": "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Metrics"
          period  = var.metric_period_seconds
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            [for func in var.monitored_lambda_functions : 
              ["AWS/Lambda", "Invocations", "FunctionName", func, { "stat": "Sum" }]
            ],
            [for func in var.monitored_lambda_functions : 
              ["AWS/Lambda", "Errors", "FunctionName", func, { "stat": "Sum" }]
            ]
          )
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Metrics"
          period  = var.metric_period_seconds
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            for func in var.monitored_lambda_functions : 
            ["AWS/Lambda", "Duration", "FunctionName", func, { "stat": "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Duration"
          period  = var.metric_period_seconds
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-dashboard"
    Component = "Monitoring"
  })
}