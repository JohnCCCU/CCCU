- vCenter data collection

| Piece | What it does | How often |
| --- | --- | --- |
| Collector | Pulls vCenter metrics → appends to CSV/DB | Every 5–10 min |
| Trainer | Trains/updates anomaly model from history | Daily/weekly |
| Scorer/Alert | Scores latest data → sends alerts/tags VMs | Every 5–10 min |

1. Collector: pull metrics from vCenter
Goal: build a time-series dataset like:

timestamp, vm, cpu_usage, mem_usage, disk_latency, net_usage

2. Model trainer: learn “normal” behavior
Goal: train an Isolation Forest per VM (simple, effective) and save models.

3. Scoring + alert loop
Goal: take the latest samples, score them, and alert on anomalies.

Here we’ll:

Load last N minutes of data.

For each VM with a model, score the latest row.

If anomalous → send a Slack/webhook/email (placeholder function).

4. Optional: feed back into vCenter
Once this works and you trust it, you can extend send_alert to:

Tag the VM via vSphere Automation SDK (e.g., tag anomaly=true).

Create an event in vCenter.

Open a ticket in your ITSM tool.

That’s just another API call away.