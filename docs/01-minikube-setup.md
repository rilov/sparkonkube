# Step 1: Minikube Setup

## Run it

```bash
./scripts/01-start-minikube.sh
```

This script:

1. Starts a Minikube profile named `spark-on-k8s` with 6 CPUs / 10GB RAM
   (adjust with `MINIKUBE_CPUS` / `MINIKUBE_MEMORY` env vars if your machine
   is smaller — Spark Operator + ArgoCD + Airflow + a notebook is a lot of
   pods, but you can scale down and disable optional components).
2. Enables the `metrics-server`, `dashboard`, and `ingress` addons.
3. Creates a `spark-jobs` namespace where all Spark driver/executor pods
   will live.

## Verify

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get namespaces
```

You should see a single `Ready` node and the `spark-jobs` namespace.

## Useful commands while iterating

```bash
minikube -p spark-on-k8s dashboard        # open the k8s dashboard
minikube -p spark-on-k8s ssh              # shell into the VM/container
kubectl config use-context spark-on-k8s   # ensure kubectl targets this cluster
kubectl get pods -A -w                    # watch every pod across namespaces
```

## Why a dedicated namespace (`spark-jobs`) for Spark workloads?

Isolating Spark driver/executor pods into their own namespace:

- Keeps RBAC scoped tightly (the Spark driver's ServiceAccount only needs
  permission to manage pods *within its own namespace*).
- Makes it trivial to apply resource quotas/limits per-namespace later.
- Mirrors how you'd organize a real OpenShift project per team/workload.

## Next

→ [`docs/02-spark-operator-setup.md`](02-spark-operator-setup.md)
