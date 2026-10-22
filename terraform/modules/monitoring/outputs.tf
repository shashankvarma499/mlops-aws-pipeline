output "log_group_name" {
  value = aws_cloudwatch_log_group.pipeline.name
}

output "latency_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.model_latency.arn
}
