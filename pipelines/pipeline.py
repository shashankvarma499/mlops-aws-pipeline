"""SageMaker Pipelines definition: train -> evaluate -> condition -> register.

Creates (or updates) the pipeline and starts an execution. Configure via
environment variables; every value has a sensible default so a first run works
with `python pipelines/pipeline.py` after Terraform + image push.

Required env (set or export before running):
  SM_ROLE_ARN           SageMaker execution role ARN (terraform output)
  SM_BUCKET             Artifacts bucket name (terraform output)
Optional env:
  AWS_REGION            default us-east-2
  TRAINING_IMAGE        default <account>.dkr.ecr.<region>.amazonaws.com/mlops-dev-training:latest
  MODEL_PACKAGE_GROUP   default mlops-dev-models
  ACCURACY_THRESHOLD    default 0.90
"""
import os
import time

import boto3
import sagemaker
from sagemaker.estimator import Estimator
from sagemaker.image_uris import retrieve as retrieve_image_uri
from sagemaker.inputs import TrainingInput
from sagemaker.model import Model
from sagemaker.processing import ProcessingInput, ProcessingOutput, ScriptProcessor
from sagemaker.workflow.conditions import ConditionGreaterThanOrEqualTo
from sagemaker.workflow.condition_step import ConditionStep
from sagemaker.workflow.functions import JsonGet
from sagemaker.workflow.model_step import ModelStep
from sagemaker.workflow.pipeline import Pipeline
from sagemaker.workflow.parameters import ParameterFloat, ParameterString
from sagemaker.workflow.steps import ProcessingStep, TrainingStep


def _env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def build_pipeline() -> Pipeline:
    session = sagemaker.Session()
    region = _env("AWS_REGION", session.boto_region_name or "us-east-2")
    account = boto3.client("sts").get_caller_identity()["Account"]

    role = _env("SM_ROLE_ARN")
    bucket = _env("SM_BUCKET")
    if not role or not bucket:
        raise SystemExit(
            "Set SM_ROLE_ARN and SM_BUCKET (see `terraform output` after apply)."
        )

    training_image = _env(
        "TRAINING_IMAGE",
        f"{account}.dkr.ecr.{region}.amazonaws.com/mlops-dev-training:latest",
    )
    model_package_group = _env("MODEL_PACKAGE_GROUP", "mlops-dev-models")
    instance_type = _env("SM_INSTANCE_TYPE", "ml.m5.large")

    # The AWS-managed XGBoost image serves the model produced by train.py.
    inference_image = retrieve_image_uri("xgboost", region, version="1.7-1")

    accuracy_threshold = ParameterFloat(
        name="AccuracyThreshold", default_value=float(_env("ACCURACY_THRESHOLD", "0.90"))
    )

    # --- Step 1: train (custom ECR image) ---
    estimator = Estimator(
        image_uri=training_image,
        role=role,
        instance_count=1,
        instance_type=instance_type,
        output_path=f"s3://{bucket}/models",
        sagemaker_session=session,
    )
    step_train = TrainingStep(name="TrainXGBoost", estimator=estimator)

    # --- Step 2: evaluate (Processing job) ---
    script_processor = ScriptProcessor(
        image_uri=training_image,
        role=role,
        instance_count=1,
        instance_type=instance_type,
        command=["python"],
        sagemaker_session=session,
    )
    step_eval = ProcessingStep(
        name="EvaluateModel",
        processor=script_processor,
        code="training/evaluate.py",
        inputs=[
            ProcessingInput(
                source=step_train.properties.ModelArtifacts.S3ModelArtifacts,
                destination="/opt/ml/processing/model",
            )
        ],
        outputs=[
            ProcessingOutput(
                source="/opt/ml/processing/evaluation",
                destination=f"s3://{bucket}/evaluation",
            )
        ],
    )

    # --- Step 3: register (only if accuracy clears the threshold) ---
    model = Model(
        image_uri=inference_image,
        model_data=step_train.properties.ModelArtifacts.S3ModelArtifacts,
        role=role,
        sagemaker_session=session,
    )
    step_register = ModelStep(
        name="RegisterModel",
        step_args=model.register(
            content_types=["text/csv"],
            response_types=["text/csv"],
            inference_instances=[instance_type],
            transform_instances=[instance_type],
            model_package_group_name=model_package_group,
            approval_status="PendingManualApproval",
        ),
    )

    # --- Condition: accuracy >= threshold ---
    cond = ConditionGreaterThanOrEqualTo(
        left=JsonGet(
            step_name=step_eval.name,
            property_file="evaluation.json",
            json_path="accuracy",
        ),
        right=accuracy_threshold,
    )
    step_condition = ConditionStep(
        name="AccuracyGate",
        conditions=[cond],
        if_steps=[step_register],
        else_steps=[],
    )

    pipeline = Pipeline(
        name="mlops-xgboost-pipeline",
        parameters=[accuracy_threshold],
        steps=[step_train, step_eval, step_condition],
        sagemaker_session=session,
    )
    return pipeline


def main() -> None:
    pipeline = build_pipeline()
    pipeline.upsert(role_arn=_env("SM_ROLE_ARN"))
    execution = pipeline.start()
    print(f"Pipeline started: {execution.arn}")
    # Poll the top-level execution status for convenience.
    for _ in range(120):
        execution.wait(delay=30, max_attempts=1)
        status = execution.describe().get("PipelineExecutionStatus")
        print(f"pipeline status: {status}")
        if status in {"Succeeded", "Failed", "Stopped"}:
            break
        time.sleep(30)


if __name__ == "__main__":
    main()
