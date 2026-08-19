# Done

You installed the stack, made Prometheus discover an application through a
Kubernetes object, read the queries a dashboard is actually made of, and proved
the metrics outlive the Pod that holds them.

**What you can now do**

- Read a target list and say which component each job comes from — control
  plane, kubelet, node-exporter, kube-state-metrics, your own app
- Write a ServiceMonitor that Prometheus **selects**, which means matching its
  `serviceMonitorSelector` and naming a Service port rather than a number
- Diagnose the silent version of that failure, where the object exists, nothing
  errors, and no target appears
- Write the CPU and memory queries behind a dashboard, and say why CPU needs
  `rate()`, why working-set is the memory number that matters, and why
  `container!=""` stops every figure reading double
- Give Prometheus a volume that survives it, and prove it did

**The habit underneath all of it**

Three of the four things that went wrong here failed **silently**. A
ServiceMonitor outside the selector, a port referenced by number, an
`emptyDir` quietly discarding history — none of them produce an error, an
event, or a red Pod. Each one is found only by asking for the result and
noticing it is missing.

That is the difference between monitoring that works and monitoring that looks
like it works, and it is why the checks here ask Prometheus what it holds
rather than asking Kubernetes what was applied.

**On EKS**

Everything you just did is unchanged there. The managed control plane means the
`apiserver`, `scheduler` and `etcd` targets may be absent or restricted —
AWS runs those and does not always expose them — but ServiceMonitor selection,
the port-name rule, cAdvisor metrics and the StatefulSet volume all behave
identically. The part that differs is the volume: EKS wants the EBS CSI driver
installed and a StorageClass to match, which is the same PVC problem in a
different costume.

**Next**

Alerting rules on top of these metrics, and what makes an alert worth waking
someone for — that is the Prometheus alerting lab. Beyond it: remote-write,
because the volume you just relied on is one disk in one place.
