# Step 3: ArgoCD Setup (GitOps)

## Why ArgoCD here?

Instead of manually re-running `helm upgrade` or `kubectl apply` every time
you change the Spark Operator's configuration or add a new `SparkApplication`,
ArgoCD continuously reconciles your cluster state against manifests stored
in a **Git repository** — the single source of truth. This is the standard
pattern for managing Spark-on-OpenShift in production.

## Install it

```bash
./scripts/03-install-argocd.sh
```

This script:

1. Installs ArgoCD's stable manifests into the `argocd` namespace.
2. Waits for `argocd-server` to become `Ready`.
3. Prints the initial `admin` password (from the
   `argocd-initial-admin-secret` Secret).
4. Registers two ArgoCD `Application` objects:
   - [`manifests/argocd/applications/spark-operator-app.yaml`](../manifests/argocd/applications/spark-operator-app.yaml) — manages the Spark Operator Helm release.
   - [`manifests/argocd/applications/spark-jobs-app.yaml`](../manifests/argocd/applications/spark-jobs-app.yaml) — manages the `SparkApplication` CRs in [`manifests/spark-jobs/`](../manifests/spark-jobs).

## Access the UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Browse to `https://localhost:8080`, log in as `admin` with the password
printed by the script. You'll see the `spark-operator` and `spark-jobs`
Applications and their live sync status/health.

## ArgoCD points at this repo's Git remote

`spark-jobs-app.yaml` is configured to sync from:

```yaml
source:
  repoURL: https://github.com/rilov/sparkonopenshift.git
  targetRevision: main
  path: manifests/spark-jobs
```

ArgoCD syncs from a **remote Git repository**, not your local filesystem.
If you fork or rename this repo, update `repoURL` to match and re-apply:

```bash
kubectl apply -f manifests/argocd/applications/spark-jobs-app.yaml
```

From then on, editing a `SparkApplication` YAML, committing, and pushing is
all it takes to deploy a change — ArgoCD's `selfHeal: true` policy also
means manual `kubectl edit` drift gets reverted automatically, enforcing
Git as the source of truth.

## The Spark Operator's Application uses a Helm chart source

`spark-operator-app.yaml` points at the upstream Helm chart repo directly.
The comment in that file shows how to switch to a **multi-source
Application** if you want ArgoCD to read `manifests/spark-operator/values.yaml`
from *this* Git repo while still pulling the chart from the upstream repo.

## Verify sync status from the CLI

```bash
kubectl -n argocd get applications
kubectl -n argocd describe application spark-operator
```

## Next

→ [`docs/04-spark-architecture.md`](04-spark-architecture.md) to understand
what actually happens inside the cluster when a SparkApplication runs.
