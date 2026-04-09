# connecting to vCenter via python

from pyVim.connect import SmartConnect, Disconnect
import ssl

VCENTER = "vcenter.mycorp.local"
USER = "administrator@vsphere.local"
PASSWORD = "your_password"

# Ignore SSL warnings for lab environments (not recommended for prod)
context = ssl._create_unverified_context()

si = SmartConnect(
    host=VCENTER,
    user=USER,
    pwd=PASSWORD,
    sslContext=context
)

print("Connected to vCenter")
# ... use `si` to query inventory and metrics
Disconnect(si)

# Pulling Data from VMware vCenter for ML 

from pyVmomi import vim
from datetime import datetime, timedelta

def get_all_vms(content):
    container = content.viewManager.CreateContainerView(
        content.rootFolder, [vim.VirtualMachine], True
    )
    return container.view

def get_perf_manager(content):
    return content.perfManager

def query_vm_cpu(content, vm, interval=300, hours=4):
    perf_manager = get_perf_manager(content)

    # Find CPU usage counter
    cpu_counter = [
        c for c in perf_manager.perfCounter
        if c.groupInfo.key == "cpu" and c.nameInfo.key == "usage"
    ][0]

    metric_id = vim.PerformanceManager.MetricId(
        counterId=cpu_counter.key, instance=""
    )

    end_time = datetime.utcnow()
    start_time = end_time - timedelta(hours=hours)

    query = vim.PerformanceManager.QuerySpec(
        entity=vm,
        metricId=[metric_id],
        intervalId=interval,
        startTime=start_time,
        endTime=end_time
    )

    stats = perf_manager.QueryStats(querySpec=[query])
    if not stats or not stats[0].value:
        return []

    return stats[0].value[0].value  # list of CPU usage samples

# build my own ML modle
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest

# Suppose you’ve built a DataFrame with columns: ["vm_name", "timestamp", "cpu_usage"]
df = pd.read_csv("vm_cpu_timeseries.csv")

# Simple example: model per VM on its CPU usage
vm_name = "AppServer01"
vm_data = df[df["vm_name"] == vm_name].sort_values("timestamp")

X = vm_data[["cpu_usage"]].values  # shape (n_samples, 1)

model = IsolationForest(
    n_estimators=100,
    contamination=0.02,
    random_state=42
)
vm_data["anomaly"] = model.fit_predict(X)  # -1 = anomaly, 1 = normal

anomalies = vm_data[vm_data["anomaly"] == -1]
print(anomalies[["timestamp", "cpu_usage"]].head())

# vCenter Workflows for ML modle

from com.vmware.cis.tagging_client import TagAssociation

tag_association = TagAssociation(stub_config)
tag_id = "urn:vmomi:InventoryServiceTag:12345678-1234-1234-1234-1234567890ab"
vm_moid = "vm-123"

tag_association.attach(
    tag_id=tag_id,
    object_id={
        "id": vm_moid,
        "type": "VirtualMachine"
    }
)
