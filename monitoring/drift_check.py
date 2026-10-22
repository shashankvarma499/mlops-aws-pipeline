"""Data-drift check: Population Stability Index (PSI) between two feature sets.

PSI is the standard MLOps drift metric — it flags when live input data has
diverged from the data the model was trained on. Run periodically (e.g. in CI
or a scheduled job) against a stored reference distribution.

Usage:
  python monitoring/drift_check.py --reference reference.csv --current current.csv

Rules of thumb: PSI < 0.1 = no drift, 0.1-0.25 = moderate, > 0.25 = significant.
"""
import argparse

import numpy as np


def psi(expected: np.ndarray, actual: np.ndarray, bins: int = 10) -> float:
    """Compute PSI for a single feature column."""
    expected = np.asarray(expected, dtype=float)
    actual = np.asarray(actual, dtype=float)

    # Shared bin edges across both distributions.
    combined = np.concatenate([expected, actual])
    edges = np.quantile(combined, np.linspace(0, 1, bins + 1))
    edges[0], edges[-1] = -np.inf, np.inf

    e_hist, _ = np.histogram(expected, bins=edges)
    a_hist, _ = np.histogram(actual, bins=edges)

    # Add a small epsilon to avoid division by zero / log(0).
    eps = 1e-6
    e_pct = (e_hist + eps) / (e_hist.sum() + eps)
    a_pct = (a_hist + eps) / (a_hist.sum() + eps)

    return float(np.sum((a_pct - e_pct) * np.log(a_pct / e_pct)))


def main() -> None:
    parser = argparse.ArgumentParser(description="PSI drift check between two CSVs")
    parser.add_argument("--reference", required=True, help="training/reference data CSV (no header)")
    parser.add_argument("--current", required=True, help="live data CSV (no header)")
    parser.add_argument("--threshold", type=float, default=0.25, help="PSI alert threshold")
    args = parser.parse_args()

    reference = np.loadtxt(args.reference, delimiter=",")
    current = np.loadtxt(args.current, delimiter=",")

    if reference.shape[1] != current.shape[1]:
        raise SystemExit("reference and current must have the same number of columns")

    drifted = 0
    for col in range(reference.shape[1]):
        score = psi(reference[:, col], current[:, col])
        if score > args.threshold:
            drifted += 1
            print(f"DRIFT  feature {col}: PSI={score:.4f}")

    total = reference.shape[1]
    print(f"drift check complete: {drifted}/{total} features exceed PSI {args.threshold}")
    if drifted:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
