# MLOps training container — XGBoost on the built-in breast-cancer dataset.
#
# Built on the SageMaker Training Toolkit so it follows the /opt/ml contract:
#   /opt/ml/input/data/...   input channels (unused here; dataset is built-in)
#   /opt/ml/model/           model artifacts written here
#   /opt/ml/output/          optional output (metrics etc.)
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /opt/ml/code

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY train.py evaluate.py ./

# SageMaker training jobs run `train`. The entrypoint uses the training toolkit
# when present; we keep a simple, explicit entrypoint for local parity.
ENTRYPOINT ["python", "train.py"]
