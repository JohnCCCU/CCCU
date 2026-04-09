
# collector.py
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
from datetime import datetime
import ssl, csv, os

VCENTER = "vcenter.local"
USER = "administrator@vsphere.local"
PWD = "password"
OUT_FILE = "vm_metrics.csv"

def connect():
    ctx = ssl._create_unverified_context()
    si = SmartConnect(host=VCENTER, user=USER, pwd=PWD, sslContext=ctx)
    return si, si.RetrieveContent()

def get_perf_counter_id(perf_manager, group, name):
    for c in perf_manager.perfCounter:
        if c.groupInfo.key == group and c.nameInfo.key == name:
            return c.key
    raise RuntimeError(f"Counter {group}.{name} not found")

def get_vms(content):
    view = content.viewManager.CreateContainerView(content.rootFolder, [vim.VirtualMachine], True)
    return view.view

def query_metric(perf_manager, entity, counter_id):
    metric = vim.PerformanceManager.MetricId(counterId=counter_id, instance="")
    spec = vim.PerformanceManager.QuerySpec(entity=entity, metricId=[metric], intervalId=300, maxSample=1)
    res = perf_manager.QueryStats(querySpec=[spec])
    if res and res[0].value:
        return res[0].value[0].value[-1]
    return None

def ensure_header(path):
    if not os.path.exists(path):
        with open(path, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["timestamp","vm","cpu_usage","mem_active","disk_latency","net_usage"])

def main():
    si, content = connect()
    perf = content.perfManager

    cpu_id  = get_perf_counter_id(perf, "cpu", "usage")
    mem_id  = get_perf_counter_id(perf, "mem", "active")
    disk_id = get_perf_counter_id(perf, "disk", "totalLatency")
    net_id  = get_perf_counter_id(perf, "net", "usage")

    ensure_header(OUT_FILE)
    now = datetime.utcnow().isoformat()

    with open(OUT_FILE, "a", newline="") as f:
        w = csv.writer(f)
        for vm in get_vms(content):
            if not vm.runtime.powerState == "poweredOn":
                continue
            cpu  = query_metric(perf, vm, cpu_id)
            mem  = query_metric(perf, vm, mem_id)
            disk = query_metric(perf, vm, disk_id)
            net  = query_metric(perf, vm, net_id)
            if cpu is None:
                continue
            w.writerow([now, vm.name, cpu, mem, disk, net])

    Disconnect(si)

if __name__ == "__main__":
    main()
