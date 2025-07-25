# =============================================================================
# AWS Serverless API Monitoring System
# =============================================================================
# A comprehensive monitoring solution for serverless APIs using AWS native services.
# This project demonstrates Infrastructure as Code (IaC) best practices with Terraform.

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
  }
}

# =============================================================================
# Provider Configuration
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = var.project_owner
    }
  }
}

# =============================================================================
# Data Sources - Discover Existing Resources
# =============================================================================

data "aws_api_gateway_rest_api" "target_api" {
  name = var.monitored_api_name
}

data "aws_lambda_function" "target_functions" {
  count         = length(var.monitored_lambda_functions)
  function_name = var.monitored_lambda_functions[count.index]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}