
# train_models.py
import pandas as pd
import os, joblib
from sklearn.ensemble import IsolationForest

DATA_FILE = "vm_metrics.csv"
MODEL_DIR = "models"
os.makedirs(MODEL_DIR, exist_ok=True)

def main():
    df = pd.read_csv(DATA_FILE)
    # basic cleaning
    df = df.dropna(subset=["cpu_usage","mem_active","disk_latency","net_usage"])

    for vm_name, group in df.groupby("vm"):
        X = group[["cpu_usage","mem_active","disk_latency","net_usage"]].values
        if len(X) < 100:  # not enough history
            continue

        model = IsolationForest(
            n_estimators=200,
            contamination=0.02,
            random_state=42
        )
        model.fit(X)
        joblib.dump(model, os.path.join(MODEL_DIR, f"{vm_name}.joblib"))
        print(f"Trained model for {vm_name}, samples={len(X)}")

if __name__ == "__main__":
    main()
