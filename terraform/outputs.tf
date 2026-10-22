output "region" {
  description = "AWS region the stack is deployed into."
  value       = data.aws_region.current.name
}

output "data_bucket" {
  description = "S3 bucket for raw/processed training data."
  value       = module.s3.data_bucket_name
}

output "artifacts_bucket" {
  description = "S3 bucket for model artifacts and pipeline outputs."
  value       = module.s3.artifacts_bucket_name
}

output "training_image_repo" {
  description = "ECR repository URI for the training image."
  value       = module.ecr.training_repo_url
}

output "inference_image_repo" {
  description = "ECR repository URI for the inference image."
  value       = module.ecr.inference_repo_url
}

output "sagemaker_role_arn" {
  description = "IAM role ARN for SageMaker execution (least privilege)."
  value       = module.iam.sagemaker_role_arn
}

output "model_package_group" {
  description = "SageMaker Model Package Group name (model registry)."
  value       = module.sagemaker.model_package_group_name
}

output "log_group_name" {
  description = "CloudWatch Log Group for pipeline/endpoint logs."
  value       = module.monitoring.log_group_name
}
