#!/usr/bin/env python3
"""
AWS Serverless API Security Monitor

This Lambda function performs automated security monitoring for serverless APIs.
It analyzes CloudWatch metrics to detect potential security threats and sends
alerts via SNS when suspicious activity is detected.

Author: DevOps Team
Project: ${project_name}
Environment: ${environment}
"""

import json
import boto3
import os
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns')

# Configuration from environment variables
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
API_NAME = os.environ['API_NAME']
SECURITY_ERROR_THRESHOLD = int(os.environ.get('SECURITY_ERROR_THRESHOLD', 10))
PROJECT_NAME = os.environ['PROJECT_NAME']
ENVIRONMENT = os.environ['ENVIRONMENT']


class SecurityMonitor:
    """Security monitoring class for serverless APIs."""
    
    def __init__(self):
        self.cloudwatch = cloudwatch
        self.sns = sns
        self.api_name = API_NAME
        self.threshold = SECURITY_ERROR_THRESHOLD
        
    def get_metric_statistics(self, metric_name: str, namespace: str, 
                            dimensions: List[Dict], start_time: datetime, 
                            end_time: datetime, period: int = 300) -> List[Dict]:
        """
        Retrieve CloudWatch metric statistics.
        
        Args:
            metric_name: Name of the CloudWatch metric
            namespace: AWS service namespace
            dimensions: Metric dimensions
            start_time: Start time for metric query
            end_time: End time for metric query
            period: Period in seconds
            
        Returns:
            List of metric data points
        """
        try:
            response = self.cloudwatch.get_metric_statistics(
                Namespace=namespace,
                MetricName=metric_name,
                Dimensions=dimensions,
                StartTime=start_time,
                EndTime=end_time,
                Period=period,
                Statistics=['Sum', 'Average', 'Maximum']
            )
            return response.get('Datapoints', [])
        except ClientError as e:
            logger.error(f"Error retrieving metric {metric_name}: {e}")
            return []
    
    def analyze_api_errors(self, hours_back: int = 1) -> Dict:
        """
        Analyze API Gateway error patterns for security threats.
        
        Args:
            hours_back: Number of hours to analyze
            
        Returns:
            Dictionary containing analysis results
        """
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(hours=hours_back)
        
        # Get 4XX errors (client errors - potential security threats)
        error_4xx_data = self.get_metric_statistics(
            metric_name='4XXError',
            namespace='AWS/ApiGateway',
            dimensions=[{'Name': 'ApiName', 'Value': self.api_name}],
            start_time=start_time,
            end_time=end_time
        )
        
        # Get 5XX errors (server errors)
        error_5xx_data = self.get_metric_statistics(
            metric_name='5XXError',
            namespace='AWS/ApiGateway',
            dimensions=[{'Name': 'ApiName', 'Value': self.api_name}],
            start_time=start_time,
            end_time=end_time
        )
        
        # Calculate totals
        total_4xx = sum([point['Sum'] for point in error_4xx_data])
        total_5xx = sum([point['Sum'] for point in error_5xx_data])
        
        # Analyze patterns
        analysis = {
            'period_hours': hours_back,
            'total_4xx_errors': total_4xx,
            'total_5xx_errors': total_5xx,
            'error_4xx_datapoints': len(error_4xx_data),
            'error_5xx_datapoints': len(error_5xx_data),
            'security_alert_threshold': self.threshold,
            'timestamp': end_time.isoformat()
        }
        
        # Detect suspicious patterns
        if error_4xx_data:
            max_4xx_in_period = max([point['Sum'] for point in error_4xx_data])
            avg_4xx_in_period = total_4xx / len(error_4xx_data) if error_4xx_data else 0
            
            analysis.update({
                'max_4xx_in_period': max_4xx_in_period,
                'avg_4xx_in_period': avg_4xx_in_period,
                'potential_attack_detected': total_4xx > self.threshold,
                'burst_detected': max_4xx_in_period > (self.threshold / 2)
            })
        
        return analysis
    
    def generate_security_alert(self, analysis: Dict) -> str:
        """
        Generate formatted security alert message.
        
        Args:
            analysis: Security analysis results
            
        Returns:
            Formatted alert message
        """
        alert_level = "🚨 CRITICAL" if analysis['total_4xx_errors'] > (self.threshold * 2) else "⚠️  WARNING"
        
        message = f"""
{alert_level} SECURITY ALERT: Suspicious API Activity Detected

Project: {PROJECT_NAME} ({ENVIRONMENT})
API Gateway: {self.api_name}
Analysis Period: {analysis['period_hours']} hour(s)
Detection Time: {analysis['timestamp']}

THREAT INDICATORS:
• Total 4XX Errors: {analysis['total_4xx_errors']} (Threshold: {self.threshold})
• Total 5XX Errors: {analysis['total_5xx_errors']}
• Error Burst Detected: {analysis.get('burst_detected', 'N/A')}

POTENTIAL SECURITY THREATS:
• Brute Force Attacks (401/403 errors)
• API Endpoint Scanning (404 errors)
• Authentication Bypass Attempts
• Unauthorized Access Attempts
• DDoS or Rate Limit Testing

IMMEDIATE ACTIONS REQUIRED:
1. Review CloudWatch Logs for detailed error patterns
2. Check source IP addresses in access logs
3. Verify authentication mechanisms
4. Consider implementing rate limiting
5. Review API Gateway access policies

Dashboard: https://console.aws.amazon.com/cloudwatch/home?region={os.environ.get('AWS_REGION', 'us-east-1')}#dashboards:name={PROJECT_NAME}-{ENVIRONMENT}-monitoring

This is an automated alert from the {PROJECT_NAME} security monitoring system.
"""
        return message.strip()
    
    def send_alert(self, message: str, subject: str) -> bool:
        """
        Send security alert via SNS.
        
        Args:
            message: Alert message content
            subject: Alert subject line
            
        Returns:
            True if alert sent successfully, False otherwise
        """
        try:
            response = self.sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=subject,
                Message=message
            )
            
            message_id = response.get('MessageId')
            logger.info(f"Security alert sent successfully. MessageId: {message_id}")
            return True
            
        except ClientError as e:
            logger.error(f"Failed to send security alert: {e}")
            return False
    
    def run_security_check(self) -> Dict:
        """
        Execute complete security monitoring check.
        
        Returns:
            Dictionary containing check results
        """
        logger.info(f"Starting security monitoring for API: {self.api_name}")
        
        # Perform security analysis
        analysis = self.analyze_api_errors()
        
        # Determine if alert should be sent
        should_alert = analysis.get('potential_attack_detected', False)
        alert_sent = False
        
        if should_alert:
            logger.warning(f"Security threat detected: {analysis['total_4xx_errors']} 4XX errors exceed threshold of {self.threshold}")
            
            # Generate and send alert
            alert_message = self.generate_security_alert(analysis)
            subject = f"🚨 Security Alert: {self.api_name} - High Error Rate Detected"
            alert_sent = self.send_alert(alert_message, subject)
        else:
            logger.info(f"No security threats detected. 4XX errors: {analysis['total_4xx_errors']}")
        
        return {
            'analysis': analysis,
            'alert_sent': alert_sent,
            'execution_timestamp': datetime.utcnow().isoformat()
        }


def lambda_handler(event, context):
    """
    AWS Lambda handler function.
    
    Args:
        event: Lambda event data
        context: Lambda context object
        
    Returns:
        Dictionary containing execution results
    """
    try:
        logger.info("Security monitoring Lambda function started")
        logger.info(f"Event: {json.dumps(event, default=str)}")
        
        # Initialize security monitor
        monitor = SecurityMonitor()
        
        # Run security check
        results = monitor.run_security_check()
        
        # Prepare response
        response = {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Security monitoring completed successfully',
                'project': PROJECT_NAME,
                'environment': ENVIRONMENT,
                'api_name': API_NAME,
                'results': results
            }, default=str)
        }
        
        logger.info("Security monitoring completed successfully")
        return response
        
    except Exception as e:
        logger.error(f"Error in security monitoring: {str(e)}", exc_info=True)
        
        # Send error notification
        try:
            error_message = f"""
Security Monitoring System Error

Project: {PROJECT_NAME} ({ENVIRONMENT})
API: {API_NAME}
Error: {str(e)}
Timestamp: {datetime.utcnow().isoformat()}

The security monitoring system encountered an error and may not be functioning properly.
Please investigate immediately.
"""
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=f"🔴 Error: Security Monitor Failure - {PROJECT_NAME}",
                Message=error_message
            )
        except Exception as sns_error:
            logger.error(f"Failed to send error notification: {sns_error}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Security monitoring failed',
                'error': str(e)
            })
        }


if __name__ == "__main__":
    # For local testing
    test_event = {}
    test_context = type('Context', (), {
        'aws_request_id': 'test-request-id',
        'function_name': 'test-function',
        'remaining_time_in_millis': lambda: 30000
    })()
    
    result = lambda_handler(test_event, test_context)
    print(json.dumps(result, indent=2, default=str))