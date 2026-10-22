output "model_package_group_name" {
  value = aws_sagemaker_model_package_group.models.model_package_group_name
}

output "model_package_group_arn" {
  value = aws_sagemaker_model_package_group.models.arn
}
