# Architecture & Design Decisions

## Overview

The pipeline trains an XGBoost classifier, evaluates it, and — only if the test
accuracy clears a configurable threshold — registers it into a SageMaker Model
Package Group (the model registry). A separate, human-gated step deploys the
registered model to a SageMaker endpoint. CloudWatch collects logs and metrics,
and a PSI-based drift check flags input-data divergence.

```
S3 data ─▶ Training job (custom ECR image) ─▶ Evaluation (Processing) ─▶ accuracy gate ─▶ Model Registry
                                                                                            │
                                                                    (manual approve)       ▼
CloudWatch ◀── metrics/logs ─── SageMaker Endpoint (XGBoost serving) ◀── deploy script / GH Actions
```

## Decisions

### 1. SageMaker (managed) over self-managed Kubernetes + Kubeflow
SageMaker Pipelines, Model Registry, and Endpoints give the full MLOps loop
without operating a K8s cluster, GPU scheduling, or a serving control plane.
Lower operational cost and faster to a working pipeline; the trade-off is
platform lock-in and less "DevOps street cred." An EKS + KServe variant is a
natural next step and the modules are structured so the training/registry
pieces carry over unchanged.

### 2. Terraform for persistent infra, SageMaker SDK for the pipeline
Terraform owns everything with a long life and a stable shape (buckets, ECR,
IAM, registry, alarms). The pipeline graph is created and executed with the
SageMaker Python SDK because it is a workflow definition, not infrastructure —
it references role ARNs and bucket names via environment variables (the
`terraform output` values), not by hard-coding.

### 3. Custom ECR training image + AWS-managed XGBoost serving image
Training uses a custom Docker image (python:3.11-slim + xgboost + the SageMaker
training toolkit) to demonstrate the containerized-training path and keep the
training logic portable. Serving reuses the AWS-managed `sagemaker-xgboost`
image so the endpoint needs no custom inference container — the model file
written by `train.py` (`xgboost-model`) is exactly what that image expects.
A dedicated ECR inference repo is still provisioned for a BYO serving path.

### 4. Model registry with `PendingManualApproval`
Registered models enter the registry in a pending state. A human (or a review
step) approves before `deploy_endpoint.sh` picks the latest **Approved**
package. This keeps a quality gate between training and production.

## Security

- S3 buckets: private, public-access blocked, versioned, SSE-AES256.
- IAM: a single SageMaker execution role with least-privilege policies scoped to
  the two buckets, the training ECR repo, `sagemaker:*` describe/create on
  models/endpoints, and `/aws/sagemaker/*` CloudWatch logs.
- No credentials in the repo. Local runs use `aws login`; CI uses GitHub OIDC
  (`role-to-assume`). If the project's managed SCP denies IAM OIDC-provider ops,
  fall back to static access-key secrets.

## Cost & cleanup

Defaults use `ml.m5.large` (a small, cheap instance; not free-tier) for
training/processing/endpoint. For pure learning runs you can drop to
`ml.t3.medium` for training/processing. **The endpoint bills continuously** —
delete it when you're done:

```bash
aws sagemaker delete-endpoint --endpoint-name mlops-dev-endpoint
aws sagemaker delete-endpoint-config --endpoint-config-name <name>
```

Tear down the rest with `terraform destroy`.

## Alternatives considered

- **EKS + Kubeflow + KServe**: most "real-world DevOps" but heavy to stand up and
  expensive for a learning account; kept as a documented follow-up.
- **Vertex AI (GCP)**: equivalent managed MLOps; AWS chosen because this account
  is AWS-primary and the user's IaC/cloud strength is Terraform + AWS.
- **SageMaker Model Monitor (built-in drift)**: replaced here by a lightweight
  PSI script (`monitoring/drift_check.py`) for clarity; Model Monitor can be
  wired in later without changing the pipeline shape.

## Roadmap

1. CI/CD retraining trigger (retrain on dataset change in S3).
2. Model Monitor for native drift/quality/bias alerts.
3. Multi-environment (dev/staging/prod) with promotion of the same model package.
4. EKS + KServe serving variant behind an API Gateway.
