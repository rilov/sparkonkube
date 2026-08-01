# Step 10: Troubleshooting

## Driver pod fails immediately with `Forbidden` errors trying to create pods

**Cause:** the `spark-driver` ServiceAccount lacks RBAC to manage
pods/services in its namespace.

**Fix:**

```bash
kubectl apply -f manifests/rbac/spark-rbac.yaml
kubectl get role,rolebinding -n spark-jobs
```

Confirm the `SparkApplication`'s `spec.driver.serviceAccount` matches
(`spark-driver`).

## `SparkApplication` stuck in `SUBMITTED` and never progresses

Check the operator's controller logs:

```bash
kubectl -n spark-operator logs deploy/spark-operator-controller -f
```

Common causes: webhook rejecting the spec (check for validation errors),
or the operator not watching the `spark-jobs` namespace
(`spark.jobNamespaces` in `manifests/spark-operator/values.yaml`).

## Executor pods never appear / driver logs show connection timeouts

Usually a networking/Service issue. Verify the driver's headless Service
was created:

```bash
kubectl get svc -n spark-jobs | grep driver-svc
```

If missing, check driver pod logs for `SparkContext` initialization errors.

## `ImagePullBackOff` on driver/executor pods

Minikube's Docker daemon may not have the image cached and your network
may be slow/offline. Pre-pull it:

```bash
minikube -p spark-on-k8s image pull docker.io/apache/spark:3.5.1
```

## ArgoCD Application stuck in `OutOfSync` / `Unknown`

- Confirm `repoURL` in `manifests/argocd/applications/spark-jobs-app.yaml`
  points to a real, reachable Git remote (not the placeholder).
- Check `kubectl -n argocd logs deploy/argocd-repo-server` for Git auth
  errors (private repos need a configured Git credential/SSH key in
  ArgoCD).

## Notebook pod pending forever

Usually insufficient CPU/memory on the Minikube VM. Check:

```bash
kubectl describe pod -n kubeflow -l notebook-name=spark-notebook
```

If you see `Insufficient cpu`/`memory` events, increase Minikube resources
(`MINIKUBE_CPUS`/`MINIKUBE_MEMORY` env vars before re-running
`scripts/01-start-minikube.sh`, or `minikube stop && minikube start
--cpus=... --memory=...` on the existing profile) or scale down other
components you're not actively using.

## Airflow `SparkKubernetesOperator` import error

Missing provider package. Install
`apache-airflow-providers-cncf-kubernetes>=7.0.0` in the Airflow image (see
`docs/07-airflow-orchestration.md`).

## `SparkKubernetesSensor` never reports success

Confirm the `application_name` Jinja template correctly resolves to the
actual `SparkApplication` name created by the preceding
`SparkKubernetesOperator` task — check the task's XCom value in the Airflow
UI (`submit_spark_pi` → XCom tab).

## General debugging checklist

```bash
kubectl get sparkapplications -A
kubectl describe sparkapplication <name> -n spark-jobs
kubectl get events -n spark-jobs --sort-by='.lastTimestamp'
kubectl logs -n spark-jobs <driver-pod-name>
```
