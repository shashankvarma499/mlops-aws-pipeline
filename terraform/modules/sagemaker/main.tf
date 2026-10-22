# Model Package Group = the model registry. Every approved model version is
# registered here; the endpoint is deployed from a specific package version.
resource "aws_sagemaker_model_package_group" "models" {
  model_package_group_name        = "${var.project}-${var.environment}-models"
  model_package_group_description = "MLOps pipeline model registry (${var.environment})"
  tags                            = var.tags
}
