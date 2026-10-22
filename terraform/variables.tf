variable "region" {
  description = "AWS region. All resources are created in this single region."
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Project/namespace prefix used in resource names."
  type        = string
  default     = "mlops"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project   = "mlops-aws-pipeline"
    ManagedBy = "terraform"
  }
}

# --- SageMaker sizing (free-tier aware defaults) ---

variable "sagemaker_training_instance_type" {
  description = "Instance type for SageMaker training jobs."
  type        = string
  default     = "ml.m5.large"
}

variable "sagemaker_processing_instance_type" {
  description = "Instance type for SageMaker processing (evaluation) jobs."
  type        = string
  default     = "ml.m5.large"
}

variable "sagemaker_endpoint_instance_type" {
  description = "Instance type for the hosted endpoint."
  type        = string
  default     = "ml.m5.large"
}

# --- Model quality gate ---

variable "accuracy_threshold" {
  description = "Minimum test accuracy required to register the model."
  type        = number
  default     = 0.90
}
