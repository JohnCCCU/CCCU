#collecting real time data from vCenter

from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import ssl, time, pandas as pd
from datetime import datetime

context = ssl._create_unverified_context()
si = SmartConnect(host="vcenter.local", user="administrator@vsphere.local", pwd="password", sslContext=context)
content = si.RetrieveContent()

def get_vms():
    view = content.viewManager.CreateContainerView(content.rootFolder, [vim.VirtualMachine], True)
    return view.view

def get_cpu_counter(perf_manager):
    for c in perf_manager.perfCounter:
        if c.groupInfo.key == "cpu" and c.nameInfo.key == "usage":
            return c.key

perf_manager = content.perfManager
cpu_counter_id = get_cpu_counter(perf_manager)

def query_cpu(vm):
    metric = vim.PerformanceManager.MetricId(counterId=cpu_counter_id, instance="")
    query = vim.PerformanceManager.QuerySpec(entity=vm, metricId=[metric], intervalId=300)
    result = perf_manager.QueryStats(querySpec=[query])
    if result and result[0].value:
        return result[0].value[0].value[-1]
    return None

rows = []
for vm in get_vms():
    cpu = query_cpu(vm)
    if cpu is not None:
        rows.append({"timestamp": datetime.utcnow(), "vm": vm.name, "cpu_usage": cpu})

df = pd.DataFrame(rows)
Disconnect(si)


# Training ML model for anomaly detection

import pandas as pd
from sklearn.ensemble import IsolationForest

df = pd.read_csv("vm_metrics.csv")
vm = "AppServer01"
subset = df[df["vm"] == vm].sort_values("timestamp")

X = subset[["cpu_usage"]].values

model = IsolationForest(contamination=0.02, random_state=42)
subset["anomaly"] = model.fit_predict(X)

anomalies = subset[subset["anomaly"] == -1]
print(anomalies[["timestamp", "cpu_usage"]].head())


