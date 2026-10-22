SHELL := /bin/bash
AWS_ACCOUNT ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)
AWS_REGION  ?= us-east-2
IMAGE       ?= mlops-training

.PHONY: help tf-init tf-plan tf-apply tf-fmt image-build image-push pipeline deploy invoke

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

tf-fmt: ## Format + validate Terraform
	cd terraform && terraform fmt -recursive && terraform validate

tf-init: ## Initialize Terraform (downloads providers)
	cd terraform && terraform init

tf-plan: ## Show the plan (requires AWS auth)
	cd terraform && terraform plan -out=plan.tfplan

tf-apply: ## Apply the plan (requires AWS auth)
	cd terraform && terraform apply plan.tfplan

image-build: ## Build the training image locally
	docker build -t $(IMAGE):latest training/

image-push: ## Build + push the training image to ECR (requires AWS auth)
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com
	docker build -t $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com/$(IMAGE):latest training/
	docker push $(AWS_ACCOUNT).dkr.ecr.$(AWS_REGION).amazonaws.com/$(IMAGE):latest

pipeline: ## Create + run a SageMaker Pipeline execution (requires AWS auth)
	python pipelines/pipeline.py

deploy: ## Deploy the registered model to an endpoint
	./scripts/deploy_endpoint.sh

invoke: ## Smoke-test the endpoint
	python scripts/invoke_endpoint.py
