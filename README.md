# EgyKode Killercoda scenarios

Hands-on scenarios for [EgyKode](https://egykode.com), free and in the browser
with nothing to install.

| Directory | Scenario | Backend |
| --- | --- | --- |
| `bash-backup-retention` | A Backup Script You Can Trust | ubuntu |
| `docker-multi-stage-build` | Production-Grade Multi-Stage Dockerfile | ubuntu |
| `docker-networks-volumes-healthchecks` | Docker Networks, Volumes and Healthchecks | ubuntu |
| `git-branching-collaboration` | Git Branching & Collaboration | ubuntu |
| `git-recovery-history` | Git Recovery: Reflog, Lost Branches and Secrets in History | ubuntu |
| `k8s-config-secrets` | Kubernetes Config & Secrets: Probes, Limits, Rollouts | kubernetes-kubeadm-1node |
| `k8s-rbac-service-accounts` | Kubernetes RBAC & Service Accounts | kubernetes-kubeadm-1node |
| `k8s-services-endpoints` | Kubernetes Services: Endpoints, DNS and the Empty List | kubernetes-kubeadm-1node |
| `k8s-storage-persistence` | Kubernetes Storage: What Survives a Pod | kubernetes-kubeadm-1node |
| `k8s-workloads` | Kubernetes Workloads: Pod, ReplicaSet, Deployment | kubernetes-kubeadm-1node |
| `linux-processes-services-logs` | Processes, Services and Logs: Find It, Read It, Fix It | ubuntu |
| `linux-users-permissions-services` | Linux Server Administration: Users, Permissions, Services | ubuntu |
| `network-layer-diagnosis` | Network Diagnosis: Name, Route, Reachability | ubuntu |
| `reverse-proxy-load-balancing` | Reverse Proxy and Load Balancing: 502 vs 504 | ubuntu |
| `tls-certificate-diagnosis` | TLS Diagnosis: Read the Certificate, Name the Layer | ubuntu |

Each is three steps with a verification script per step, a setup script that
builds the starting state, and a finish page.

## Why this repository exists

Killercoda scans a repository's **root** for directories containing
`index.json`. In the main EgyKode repository these live under
`killercoda/`, and connecting it synced correctly and published nothing —
twice, silently. A repository whose root is the scenarios has no such
ambiguity.

## This repository is generated

The sources live in [the main EgyKode repository](https://github.com/Waleeddarwesh/EgyKode)
under `killercoda/`. Edit them there; `scripts/sync-scenarios.mjs`
regenerates this mirror and CI fails when the two drift. Changes made directly
here are lost on the next sync.
