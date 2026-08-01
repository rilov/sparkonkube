# Step 2: Kubeflow Spark Operator Setup

## What is the Spark Operator?

The [Kubeflow Spark Operator](https://github.com/kubeflow/spark-operator) is
a Kubernetes controller that watches for two Custom Resource Definitions
(CRDs):

- **`SparkApplication`** — a one-shot or long-running Spark job, declared
  declaratively instead of run as an imperative `spark-submit` command.
- **`ScheduledSparkApplication`** — a cron-scheduled wrapper around
  `SparkApplication`, run entirely inside the cluster (no external scheduler
  needed for simple, fixed-interval jobs — see `docs/07-airflow-orchestration.md`
  for when you *do* want an external scheduler like Airflow).

When you `kubectl apply` a `SparkApplication`, the operator's controller:

1. Validates the spec via an admission webhook.
2. Translates it into a `spark-submit` invocation with `--master k8s://...`
   and all the driver/executor pod template options as arguments.
3. Launches the **driver pod**, which itself talks to the Kubernetes API to
   launch **executor pods** (see `docs/04-spark-architecture.md` for the
   full lifecycle).
4. Tracks the SparkApplication's `.status` field with phase transitions
   (`SUBMITTED` → `RUNNING` → `COMPLETED`/`FAILED`) that you can watch with
   `kubectl get sparkapplications -w`.

## Install it

```bash
./scripts/02-install-spark-operator.sh
```

This script:

1. Adds the `spark-operator` Helm repo and installs the chart into the
   `spark-operator` namespace using [`manifests/spark-operator/values.yaml`](../manifests/spark-operator/values.yaml).
2. Waits for the controller pod to become `Ready`.
3. Confirms the `sparkapplications.sparkoperator.k8s.io` and
   `scheduledsparkapplications.sparkoperator.k8s.io` CRDs are registered.
4. Applies [`manifests/rbac/spark-rbac.yaml`](../manifests/rbac/spark-rbac.yaml),
   which creates the `spark-driver` ServiceAccount/Role/RoleBinding that
   every SparkApplication in this tutorial uses.

## Verify

```bash
kubectl -n spark-operator get pods
kubectl get crd | grep sparkoperator.k8s.io
kubectl get sa,role,rolebinding -n spark-jobs
```

## Key `values.yaml` settings explained

```yaml
spark:
  jobNamespaces: [""]   # watch ALL namespaces (spark-jobs, kubeflow, airflow)
webhook:
  enable: true          # validates SparkApplication specs before admission
```

Watching all namespaces means the operator will react to SparkApplication
CRs submitted from anywhere in the cluster — including from an Airflow
worker pod or a Kubeflow Notebook pod, which is exactly what later steps do.

## Next

→ [`docs/03-argocd-setup.md`](03-argocd-setup.md)
