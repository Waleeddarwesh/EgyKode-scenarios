# Monitoring a cluster you did not configure by hand

`kube-prometheus-stack` installs Prometheus, Grafana, the Prometheus Operator,
`node-exporter` and `kube-state-metrics` in one chart — and wires them together
so that adding a scrape target is a Kubernetes object rather than an edit to
`prometheus.yml` followed by a reload.

You will check what it already watches, make it discover your own application,
read CPU and memory for that application in Grafana, and then prove the metrics
survive Prometheus itself being deleted.

## About the "on EKS" in the lab title

This runs on a real kubeadm cluster, not EKS — and for once that changes
nothing. Read the four success criteria: Prometheus targets, a ServiceMonitor,
a Grafana graph, and metrics surviving a Pod restart. **Not one of them is an
AWS behaviour.** They are all properties of Kubernetes and of the operator, so
they are demonstrated here exactly as they would be on a managed cluster.

What EKS changes is who patches the control plane and where the volume comes
from. What a ServiceMonitor selector matches is identical on both, and it is the
part that goes wrong.

## What is being set up for you

- **kube-prometheus-stack**, with Alertmanager switched off — routing an alert
  is a different lab, and this one has enough moving parts
- **A default StorageClass**, installed if the cluster has none, because
  criterion 4 needs a real volume
- **An application in the `shop` namespace** exposing `/metrics`, with a
  Service created the way most people create one. That Service has a problem
  you will find in step 2.

Setup takes a few minutes — the chart pulls a lot of images. Step 1 waits for it.
