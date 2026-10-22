# MLOps Pipeline on AWS (SageMaker + Terraform + GitHub Actions)

A complete, deployable MLOps pipeline for training, registering, deploying, and
monitoring machine-learning models on AWS. Built as Infrastructure-as-Code with
Terraform, orchestrated by GitHub Actions, and driven by SageMaker Pipelines.

> **Purpose:** a real, hands-on MLOps reference you can run in your own AWS
> account and point to as proof of ML-infrastructure work. Every component below
> is deployable; nothing is mocked.

## Architecture

```
┌──────────────┐   ┌─────────────────────┐   ┌──────────────────────┐
│  Raw data     │──▶│  SageMaker Pipeline  │──▶│  Model Registry       │
│  (S3)         │   │  Train → Eval →      │   │  (ModelPackageGroup)  │
│               │   │  Condition → Register│   │                      │
└──────────────┘   └─────────────────────┘   └───────────┬──────────┘
                                                          │ approve
                                                          ▼
┌──────────────┐   ┌─────────────────────┐   ┌──────────────────────┐
│  Invoke       │◀──│  SageMaker Endpoint  │◀──│  Deploy (GH Actions) │
│  (smoke test) │   │  (XGBoost serving)   │   │                      │
└──────────────┘   └─────────────────────┘   └──────────────────────┘
        │                                            ▲
        └────────────  CloudWatch metrics / alarms ───┘
```

**Stack:** S3 (data + model artifacts) · ECR (training image) · SageMaker
(Training, Pipelines, Model Registry, Endpoints) · IAM (least-privilege) ·
CloudWatch (logs + alarms) · Terraform · GitHub Actions.

## Repository layout

```
terraform/            Infrastructure-as-Code (Terraform, AWS provider)
  modules/
    s3/               data + model-artifact buckets (versioned, encrypted)
    ecr/              training + inference image repositories
    iam/              SageMaker execution role (least privilege)
    sagemaker/        model package group (registry)
    monitoring/       CloudWatch log group + endpoint latency alarm
  environments/
    dev/              per-environment variable overrides
training/             Custom training container (XGBoost)
  Dockerfile          python:3.11-slim + xgboost + sagemaker-training
  train.py            trains XGBoost, writes model to /opt/ml/model
  evaluate.py         computes accuracy/precision/recall -> metrics JSON
pipelines/pipeline.py SageMaker Pipelines definition (train -> eval -> register)
scripts/              deploy + smoke-test helpers
monitoring/           data-drift check
.github/workflows/    CI (lint/validate) + ML pipeline (build->train->register->deploy)
docs/architecture.md  design decisions
```

## Quick start

### 1. Prerequisites

- AWS CLI v2, authenticated (`aws login`), configured for `us-east-2`.
- Terraform `>= 1.5`.
- Docker (to build the training image).
- GitHub repo with Actions enabled.

### 2. Provision infrastructure (once)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This creates the S3 buckets, ECR repos, IAM role, Model Package Group, and
CloudWatch resources. The `dev` environment defaults to free-tier-friendly
SageMaker instance types (see `variables.tf`).

### 3. Build & push the training image

```bash
cd training
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-2.amazonaws.com
docker build -t <account>.dkr.ecr.us-east-2.amazonaws.com/mlops-training:latest .
docker push <account>.dkr.ecr.us-east-2.amazonaws.com/mlops-training:latest
```

### 4. Run the pipeline

```bash
python pipelines/pipeline.py   # creates + starts a SageMaker Pipeline execution
```

The pipeline trains the model, evaluates it, and registers it into the Model
Package Group only if accuracy clears the threshold.

### 5. Deploy + smoke test

```bash
./scripts/deploy_endpoint.sh    # creates a SageMaker endpoint from the registered model
python scripts/invoke_endpoint.py
```

### 6. Automate with GitHub Actions

The workflow `.github/workflows/mlops-pipeline.yml` runs build → train →
register → (manual approve) → deploy. Configure OIDC or repo secrets for AWS
credentials (see `docs/architecture.md`).

## Sample model

`training/train.py` trains an XGBoost binary classifier on the built-in
scikit-learn breast-cancer dataset (deterministic, offline). Swap in your own
data by pointing the training step at an S3 URI — the pipeline shape stays the
same.

## Security notes

- Buckets are private (public-access blocked), versioned, and encrypted.
- The SageMaker role follows least privilege (scoped S3 prefixes, ECR repos,
  CloudWatch logs).
- No credentials are stored in the repo; AWS auth goes through `aws login` /
  GitHub OIDC.
