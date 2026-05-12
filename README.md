# AWS Serverless Monitoring

Monitoring system for serverless APIs. Tracks API Gateway and Lambda metrics, sends alerts via SNS, and detects security threats.

## What It Does

- Monitors API Gateway errors and latency
- Tracks Lambda function performance
- Sends email alerts when thresholds are exceeded
- Detects potential security threats (brute force, scanning)
- Creates CloudWatch dashboard

## Tech

- Terraform
- CloudWatch
- SNS
- Lambda (Python)
- EventBridge

## Setup

```bash
git clone https://github.com/KeithMV/aws-serverless-monitoring.git
cd aws-serverless-monitoring

# Edit terraform.tfvars with your API name and email
terraform init
terraform apply
```

## Configuration

```hcl
monitored_api_name = "your-api-name"
monitored_lambda_functions = ["function1", "function2"]
alert_email = "you@example.com"
```

Keith Vose | kmvose@gmail.com
