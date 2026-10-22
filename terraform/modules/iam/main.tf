locals {
  name = "${var.project}-${var.environment}-sagemaker-execution"
}

# Execution role assumed by the SageMaker service.
resource "aws_iam_role" "sagemaker_execution" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "sagemaker.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# Least-privilege policy: scoped S3 prefixes, the training ECR repo, SageMaker
# endpoints/models, and CloudWatch logs under /aws/sagemaker.
resource "aws_iam_role_policy" "sagemaker_execution" {
  name = "${local.name}-policy"
  role = aws_iam_role.sagemaker_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [
          var.data_bucket_arn,
          "${var.data_bucket_arn}/*",
          var.artifacts_bucket_arn,
          "${var.artifacts_bucket_arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = [
          var.training_repo_arn,
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/sagemaker/*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sagemaker:AddTags",
          "sagemaker:CreateModel",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:CreateEndpoint",
          "sagemaker:UpdateEndpoint",
          "sagemaker:InvokeEndpoint",
          "sagemaker:DescribeModel",
          "sagemaker:DescribeEndpoint",
          "sagemaker:DescribeEndpointConfig",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:DescribeProcessingJob",
          "sagemaker:ListTags",
          "sagemaker:CreateModelPackage",
          "sagemaker:UpdateModelPackage",
        ]
        Resource = "*"
      },
    ]
  })
}
