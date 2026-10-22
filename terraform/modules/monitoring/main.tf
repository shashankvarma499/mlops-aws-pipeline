locals {
  name = "${var.project}-${var.environment}"
}

# SageMaker writes pipeline + endpoint logs under /aws/sagemaker/*.
resource "aws_cloudwatch_log_group" "pipeline" {
  name              = "/aws/sagemaker/${local.name}"
  retention_in_days = 30
  tags              = var.tags
}

# Endpoint latency alarm. Reports INSUFFICIENT_DATA until the endpoint is
# created by scripts/deploy_endpoint.sh (SageMaker publishes ModelLatency).
resource "aws_cloudwatch_metric_alarm" "model_latency" {
  alarm_name          = "${local.name}-model-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ModelLatency"
  namespace           = "AWS/SageMaker"
  period              = 300
  statistic           = "Average"
  threshold           = 5000 # milliseconds

  dimensions = {
    EndpointName = var.endpoint_name
    VariantName  = "AllTraffic"
  }

  alarm_description = "Average model inference latency over 5000 ms for 2 consecutive 5-minute periods."
  alarm_actions     = []
  ok_actions        = []
  tags              = var.tags
}
