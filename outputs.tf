# =============================================================================
# Output Values
# =============================================================================
# These outputs provide important information about the deployed infrastructure

output "project_info" {
  description = "Basic project information"
  value = {
    project_name = var.project_name
    environment  = var.environment
    aws_region   = var.aws_region
    deployment_time = timestamp()
  }
}

output "monitoring_targets" {
  description = "Resources being monitored"
  value = {
    api_gateway_name    = var.monitored_api_name
    lambda_functions    = var.monitored_lambda_functions
    total_functions     = length(var.monitored_lambda_functions)
  }
}

output "sns_configuration" {
  description = "SNS topic and subscription information"
  value = {
    topic_arn           = aws_sns_topic.monitoring_alerts.arn
    topic_name          = aws_sns_topic.monitoring_alerts.name
    primary_email       = var.alert_email
    additional_emails   = var.additional_alert_emails
    total_subscriptions = 1 + length(var.additional_alert_emails)
  }
}

output "cloudwatch_alarms" {
  description = "Created CloudWatch alarms"
  value = {
    api_gateway_alarms = [
      "api-4xx-errors",
      "api-5xx-errors", 
      "api-high-latency"
    ]
    lambda_alarms_per_function = [
      "errors",
      "duration", 
      "throttles"
    ]
    total_lambda_alarms = length(var.monitored_lambda_functions) * 3
    security_monitor_alarms = var.enable_security_monitoring ? 1 : 0
  }
}

output "dashboard_info" {
  description = "CloudWatch dashboard information"
  value = var.enable_dashboard ? {
    dashboard_name = aws_cloudwatch_dashboard.api_monitoring[0].dashboard_name
    dashboard_url  = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.api_monitoring[0].dashboard_name}"
    enabled        = true
  } : {
    enabled = false
    message = "Dashboard creation disabled"
  }
}

output "security_monitoring" {
  description = "Security monitoring configuration"
  value = var.enable_security_monitoring ? {
    function_name     = aws_lambda_function.security_monitor[0].function_name
    function_arn      = aws_lambda_function.security_monitor[0].arn
    schedule          = var.monitoring_schedule
    error_threshold   = var.security_error_threshold
    log_group         = aws_cloudwatch_log_group.security_monitor_logs[0].name
    enabled           = true
  } : {
    enabled = false
    message = "Security monitoring disabled"
  }
}

output "alert_thresholds" {
  description = "Configured alert thresholds"
  value = {
    api_4xx_errors              = var.api_error_threshold
    lambda_duration_ms          = var.lambda_duration_threshold_ms
    security_errors_per_hour    = var.security_error_threshold
    alarm_evaluation_periods    = var.alarm_evaluation_periods
    metric_period_seconds       = var.metric_period_seconds
  }
}

output "next_steps" {
  description = "Post-deployment action items"
  value = [
    "1. ✉️  Check your email(s) and confirm SNS subscription(s)",
    "2. 📊 Visit the CloudWatch Dashboard to view real-time metrics",
    "3. 🧪 Test the monitoring system by generating some API errors",
    "4. ⚙️  Customize alert thresholds in variables.tf as needed",
    "5. 📖 Review the README.md for operational procedures",
    "6. 🔐 Verify security monitoring is functioning correctly"
  ]
}

output "useful_commands" {
  description = "Helpful AWS CLI commands for managing this infrastructure"
  value = {
    view_logs = "aws logs tail /aws/lambda/${var.project_name}-${var.environment}-security-monitor --follow"
    test_security_function = "aws lambda invoke --function-name ${var.project_name}-${var.environment}-security-monitor response.json"
    list_alarms = "aws cloudwatch describe-alarms --alarm-name-prefix ${var.project_name}-${var.environment}"
    dashboard_url = var.enable_dashboard ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-${var.environment}-monitoring" : "Dashboard not enabled"
  }
}

output "cost_optimization_tips" {
  description = "Tips for optimizing costs"
  value = [
    "💰 CloudWatch alarms cost $0.10/month each after the first 10 free alarms",
    "📊 CloudWatch dashboard widgets cost $3/month per dashboard",
    "🔍 Lambda invocations for security monitoring: ~2,880/month at current schedule",
    "📈 Consider adjusting monitoring_schedule if costs are a concern",
    "🎯 Use alarm evaluation periods wisely to avoid false positives"
  ]
}

output "troubleshooting" {
  description = "Common troubleshooting steps"
  value = {
    no_alerts_received = "Check SNS subscription confirmation and spam folder"
    false_positives = "Adjust thresholds in variables.tf and redeploy"
    missing_metrics = "Verify target API/Lambda functions exist and have traffic"
    lambda_errors = "Check CloudWatch Logs for the security monitoring function"
    dashboard_empty = "Ensure your API and Lambda functions are receiving traffic"
  }
}

# Sensitive outputs (marked as sensitive)
output "internal_resources" {
  description = "Internal resource identifiers (sensitive)"
  sensitive   = true
  value = {
    security_monitor_role_arn = var.enable_security_monitoring ? aws_iam_role.security_monitor_role[0].arn : null
    sns_topic_arn            = aws_sns_topic.monitoring_alerts.arn
    dlq_arn                  = var.enable_security_monitoring ? aws_sqs_queue.security_monitor_dlq[0].arn : null
  }
}