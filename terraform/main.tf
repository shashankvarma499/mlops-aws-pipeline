data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "s3" {
  source      = "./modules/s3"
  project     = var.project
  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id
  tags        = var.tags
}

module "ecr" {
  source      = "./modules/ecr"
  project     = var.project
  environment = var.environment
  tags        = var.tags
}

module "iam" {
  source               = "./modules/iam"
  project              = var.project
  environment          = var.environment
  region               = var.region
  account_id           = data.aws_caller_identity.current.account_id
  data_bucket_arn      = module.s3.data_bucket_arn
  artifacts_bucket_arn = module.s3.artifacts_bucket_arn
  training_repo_arn    = module.ecr.training_repo_arn
  tags                 = var.tags
}

module "sagemaker" {
  source      = "./modules/sagemaker"
  project     = var.project
  environment = var.environment
  tags        = var.tags
}

module "monitoring" {
  source      = "./modules/monitoring"
  project     = var.project
  environment = var.environment
  tags        = var.tags
}
