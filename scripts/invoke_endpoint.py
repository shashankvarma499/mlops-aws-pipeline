"""Smoke-test the deployed SageMaker XGBoost endpoint.

Sends a real sample row (CSV, the format the XGBoost container expects) and
prints the prediction. Confirms the endpoint is live and serving.

Usage:
  python scripts/invoke_endpoint.py [endpoint-name] [region]
"""
import json
import os
import sys

import boto3
from sklearn.datasets import load_breast_cancer


def main() -> None:
    endpoint = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "ENDPOINT_NAME", "mlops-dev-endpoint"
    )
    region = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("AWS_REGION", "us-east-2")

    X, y = load_breast_cancer(return_X_y=True)
    sample = X[0]  # one 30-feature row

    # XGBoost container expects CSV without a header.
    payload = ",".join(str(v) for v in sample)

    client = boto3.client("sagemaker-runtime", region_name=region)
    resp = client.invoke_endpoint(
        EndpointName=endpoint,
        ContentType="text/csv",
        Body=payload,
    )
    body = json.loads(resp["Body"].read().decode())
    print(f"true label: {int(y[0])}")
    print(f"prediction: {body}")
    print(f"endpoint:   {endpoint}")


if __name__ == "__main__":
    main()
