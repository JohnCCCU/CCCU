
# score_and_alert.py
import pandas as pd
import os, joblib, requests
from datetime import datetime, timedelta

DATA_FILE = "vm_metrics.csv"
MODEL_DIR = "models"
ALERT_WEBHOOK = "https://your-alert-endpoint"  # Slack, Teams, etc.

def send_alert(vm, row, score):
    payload = {
        "text": f"[vCenter Anomaly] VM={vm}, score={score:.3f}, "
                f"cpu={row['cpu_usage']}, mem={row['mem_active']}, "
                f"disk={row['disk_latency']}, net={row['net_usage']}, "
                f"ts={row['timestamp']}"
    }
    try:
        requests.post(ALERT_WEBHOOK, json=payload, timeout=5)
    except Exception as e:
        print("Alert failed:", e)

def main():
    df = pd.read_csv(DATA_FILE, parse_dates=["timestamp"])
    cutoff = datetime.utcnow() - timedelta(minutes=10)
    recent = df[df["timestamp"] >= cutoff]

    for vm, group in recent.groupby("vm"):
        model_path = os.path.join(MODEL_DIR, f"{vm}.joblib")
        if not os.path.exists(model_path):
            continue

        model = joblib.load(model_path)
        latest = group.sort_values("timestamp").iloc[-1]
        X = latest[["cpu_usage","mem_active","disk_latency","net_usage"]].values.reshape(1, -1)

        pred = model.predict(X)[0]      # 1 = normal, -1 = anomaly
        score = -model.score_samples(X)[0]  # higher = more anomalous

        if pred == -1:
            print(f"Anomaly detected on {vm} at {latest['timestamp']}, score={score}")
            send_alert(vm, latest, score)

if __name__ == "__main__":
    main()
