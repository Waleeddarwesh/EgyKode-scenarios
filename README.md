# EgyKode Killercoda scenarios

Hands-on scenarios for [EgyKode](https://egykode.com), free and in the browser
with nothing to install.

| Directory | Scenario | Backend |
| --- | --- | --- |
| `docker-multi-stage-build` | Production-Grade Multi-Stage Dockerfile | ubuntu |
| `git-branching-collaboration` | Git Branching & Collaboration | ubuntu |
| `k8s-workloads` | Kubernetes Workloads: Pod, ReplicaSet, Deployment | kubernetes-kubeadm-1node |

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
