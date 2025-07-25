# =============================================================================
# Variable Definitions
# =============================================================================
# Configure the monitoring system by setting these variables in terraform.tfvars
# or through environment variables.

# =============================================================================
# Project Configuration
# =============================================================================

variable "project_name" {
  description = "Name of the monitoring project"
  type        = string
  default     = "serverless-api-monitoring"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project_name))
    error_message = "Project name must start with a letter, contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_owner" {
  description = "Owner or team responsible for this project"
  type        = string
  default     = "DevOps-Team"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# =============================================================================
# Monitoring Targets
# =============================================================================

variable "monitored_api_name" {
  description = "Name of the existing API Gateway to monitor"
  type        = string
  default     = "my-serverless-api"

  validation {
    condition     = length(var.monitored_api_name) > 0
    error_message = "API name cannot be empty."
  }
}

variable "monitored_lambda_functions" {
  description = "List of existing Lambda functions to monitor"
  type        = list(string)
  default = [
    "api-auth-handler",
    "api-data-processor", 
    "api-file-handler",
    "api-notification-service"
  ]

  validation {
    condition     = length(var.monitored_lambda_functions) > 0
    error_message = "At least one Lambda function must be specified for monitoring."
  }
}

# =============================================================================
# Alert Configuration
# =============================================================================

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
  default     = "alerts@example.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Please provide a valid email address."
  }
}

variable "additional_alert_emails" {
  description = "Additional email addresses for alerts"
  type        = list(string)
  default     = []
}

# =============================================================================
# Alert Thresholds
# =============================================================================

variable "api_error_threshold" {
  description = "Number of 4XX errors before triggering an alert"
  type        = number
  default     = 5

  validation {
    condition     = var.api_error_threshold > 0
    error_message = "Error threshold must be greater than 0."
  }
}

variable "lambda_duration_threshold_ms" {
  description = "Lambda execution duration threshold in milliseconds"
  type        = number
  default     = 10000

  validation {
    condition     = var.lambda_duration_threshold_ms > 0
    error_message = "Duration threshold must be greater than 0."
  }
}

variable "security_error_threshold" {
  description = "Number of 4XX errors per hour that triggers security alert"
  type        = number
  default     = 10

  validation {
    condition     = var.security_error_threshold > 0
    error_message = "Security threshold must be greater than 0."
  }
}

variable "monitoring_schedule" {
  description = "Schedule expression for security monitoring (CloudWatch Events syntax)"
  type        = string
  default     = "rate(15 minutes)"

  validation {
    condition     = can(regex("^(rate\\([0-9]+ (minute|minutes|hour|hours|day|days)\\)|cron\\(.+\\))$", var.monitoring_schedule))
    error_message = "Schedule must be a valid CloudWatch Events rate or cron expression."
  }
}

# =============================================================================
# Feature Flags
# =============================================================================

variable "enable_security_monitoring" {
  description = "Enable automated security monitoring Lambda function"
  type        = bool
  default     = true
}

variable "enable_dashboard" {
  description = "Create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring (additional costs apply)"
  type        = bool
  default     = false
}

# =============================================================================
# Advanced Configuration
# =============================================================================

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarm state"
  type        = number
  default     = 2

  validation {
    condition     = var.alarm_evaluation_periods >= 1 && var.alarm_evaluation_periods <= 24
    error_message = "Evaluation periods must be between 1 and 24."
  }
}

variable "metric_period_seconds" {
  description = "Period for metric evaluation in seconds"
  type        = number
  default     = 300

  validation {
    condition     = contains([60, 300, 900, 3600], var.metric_period_seconds)
    error_message = "Period must be one of: 60, 300, 900, or 3600 seconds."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}