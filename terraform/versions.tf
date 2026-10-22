terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state: create the state bucket first (see README / docs/architecture.md),
  # then uncomment. Replace <account-id> with your AWS account id.
  #
  # backend "s3" {
  #   bucket         = "mlops-tfstate-<account-id>"
  #   key            = "mlops-aws-pipeline/terraform.tfstate"
  #   region         = "us-east-2"
  #   encrypt        = true
  #   dynamodb_table = "mlops-tfstate-lock"
  # }
}
