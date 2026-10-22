#!/usr/bin/env bash
# Deploy the latest approved model from the registry to a SageMaker endpoint.
# Uses the AWS-managed XGBoost image (no custom serving container needed).
set -euo pipefail

REGION="${AWS_REGION:-us-east-2}"
GROUP="${MODEL_PACKAGE_GROUP:-mlops-dev-models}"
ENDPOINT="${ENDPOINT_NAME:-mlops-dev-endpoint}"
ROLE="${SM_ROLE_ARN:?set SM_ROLE_ARN (terraform output sagemaker_role_arn)}"
INSTANCE_TYPE="${SM_INSTANCE_TYPE:-ml.m5.large}"

# Prefer the latest Approved package; fall back to the most recent if none is
# approved yet (useful right after a first pipeline run).
MODEL_PACKAGE_ARN=$(aws sagemaker list-model-packages \
  --model-package-group-name "$GROUP" \
  --model-approval-status Approved \
  --sort-by CreationTime --sort-order Descending --max-results 1 \
  --query 'ModelPackageSummaryList[0].ModelPackageArn' --output text 2>/dev/null || true)

if [ -z "$MODEL_PACKAGE_ARN" ] || [ "$MODEL_PACKAGE_ARN" = "None" ]; then
  echo "No Approved package; using the most recent package version."
  MODEL_PACKAGE_ARN=$(aws sagemaker list-model-packages \
    --model-package-group-name "$GROUP" \
    --sort-by CreationTime --sort-order Descending --max-results 1 \
    --query 'ModelPackageSummaryList[0].ModelPackageArn' --output text)
fi

echo "Deploying $MODEL_PACKAGE_ARN -> endpoint $ENDPOINT"

MODEL_NAME="${ENDPOINT}-$(date +%s)"

aws sagemaker create-model \
  --model-name "$MODEL_NAME" \
  --primary-container "ModelPackageName=${MODEL_PACKAGE_ARN}" \
  --execution-role-arn "$ROLE" >/dev/null

aws sagemaker create-endpoint-config \
  --endpoint-config-name "${MODEL_NAME}-config" \
  --production-variants \
    "VariantName=AllTraffic,ModelName=${MODEL_NAME},InitialInstanceCount=1,InstanceType=${INSTANCE_TYPE}" >/dev/null

aws sagemaker create-endpoint \
  --endpoint-name "$ENDPOINT" \
  --endpoint-config-name "${MODEL_NAME}-config" >/dev/null

echo "Endpoint '$ENDPOINT' is creating. Poll with:"
echo "  aws sagemaker describe-endpoint --endpoint-name $ENDPOINT --query EndpointStatus"
