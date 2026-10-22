variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "data_bucket_arn" {
  type = string
}

variable "artifacts_bucket_arn" {
  type = string
}

variable "training_repo_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
