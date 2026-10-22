"""Evaluation step for the SageMaker pipeline.

Runs as a SageMaker Processing job. Reads the trained model artifact from
/opt/ml/processing/model, evaluates it on the held-out test set, and writes the
metrics to /opt/ml/processing/evaluation/evaluation.json — the path the
ConditionStep reads to decide whether to register the model.
"""
import json
import os

import joblib
import xgboost as xgb
from sklearn.datasets import load_breast_cancer
from sklearn.metrics import accuracy_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

MODEL_PATH = os.path.join("/opt/ml/processing/model", "xgboost-model")
EVAL_DIR = "/opt/ml/processing/evaluation"
os.makedirs(EVAL_DIR, exist_ok=True)


def main() -> None:
    data = load_breast_cancer(as_frame=True)
    X, y = data.data, data.target
    _, X_test, _, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    booster = xgb.Booster()
    booster.load_model(MODEL_PATH)
    dtest = xgb.DMatrix(X_test)
    preds = (booster.predict(dtest) > 0.5).astype(int)

    metrics = {
        "accuracy": round(float(accuracy_score(y_test, preds)), 4),
        "precision": round(float(precision_score(y_test, preds)), 4),
        "recall": round(float(recall_score(y_test, preds)), 4),
    }

    out = os.path.join(EVAL_DIR, "evaluation.json")
    with open(out, "w") as f:
        json.dump(metrics, f)

    # Also keep the feature metadata for downstream helpers.
    meta = os.path.join("/opt/ml/processing/model", "metadata.joblib")
    if os.path.exists(meta):
        joblib.dump(joblib.load(meta), os.path.join(EVAL_DIR, "metadata.joblib"))

    print(f"evaluation: {json.dumps(metrics)}")


if __name__ == "__main__":
    main()
