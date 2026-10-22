variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "endpoint_name" {
  description = "SageMaker endpoint the latency alarm watches (created by the deploy script)."
  type        = string
  default     = "mlops-dev-endpoint"
}

variable "tags" {
  type    = map(string)
  default = {}
}
