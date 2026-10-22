variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "account_id" {
  description = "AWS account id, appended to bucket names for global uniqueness."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
