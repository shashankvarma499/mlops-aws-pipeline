output "sagemaker_role_arn" {
  value = aws_iam_role.sagemaker_execution.arn
}

output "sagemaker_role_name" {
  value = aws_iam_role.sagemaker_execution.name
}
