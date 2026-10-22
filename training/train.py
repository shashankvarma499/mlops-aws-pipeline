"""Train an XGBoost binary classifier.

Follows the SageMaker training contract: the trained model is written to
/opt/ml/model (defaults to ./model locally) so it can be packaged into
model.tar.gz and served by the AWS-managed XGBoost container.

The dataset is scikit-learn's built-in breast-cancer set so the script runs
fully offline and deterministically — swap in your own data by replacing the
load step with an S3 read of /opt/ml/input/data/train/.
"""
import json
import os

import joblib
import xgboost as xgb
from sklearn.datasets import load_breast_cancer
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split

MODEL_DIR = os.environ.get("SM_MODEL_DIR", "/opt/ml/model")
MODEL_DIR = MODEL_DIR if os.path.isdir(MODEL_DIR) else os.environ.get("MODEL_DIR", "./model")
os.makedirs(MODEL_DIR, exist_ok=True)


def main() -> None:
    data = load_breast_cancer(as_frame=True)
    X, y = data.data, data.target
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = xgb.XGBClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        objective="binary:logistic",
        eval_metric="logloss",
        random_state=42,
    )
    model.fit(X_train, y_train)

    acc = accuracy_score(y_test, model.predict(X_test))
    print(f"test accuracy: {acc:.4f}")

    # Save the model in the format the XGBoost serving container expects.
    model_path = os.path.join(MODEL_DIR, "xgboost-model")
    model.save_model(model_path)

    # Persist feature names for the evaluation + invoke helpers.
    joblib.dump({"feature_names": list(X.columns)}, os.path.join(MODEL_DIR, "metadata.joblib"))

    # Write metrics so SageMaker surfaces them in the training job.
    with open(os.path.join(MODEL_DIR, "metrics.json"), "w") as f:
        json.dump({"accuracy": round(float(acc), 4)}, f)

    print(f"model saved to {model_path}")


if __name__ == "__main__":
    main()
