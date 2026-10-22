output "training_repo_name" {
  value = aws_ecr_repository.training.name
}

output "training_repo_url" {
  value = aws_ecr_repository.training.repository_url
}

output "training_repo_arn" {
  value = aws_ecr_repository.training.arn
}

output "inference_repo_name" {
  value = aws_ecr_repository.inference.name
}

output "inference_repo_url" {
  value = aws_ecr_repository.inference.repository_url
}
