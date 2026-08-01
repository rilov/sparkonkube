# Step 4: Spark Architecture on Kubernetes — Driver & Executor Explained

This is the conceptual core of the tutorial. Understanding this will make
every later step (notebooks, Airflow, ArgoCD) make sense.

## The players

| Role | What it is | Where it runs |
|------|-----------|-----------------|
| **Client** | Whatever issues the initial `spark-submit` (or in our case, whatever creates the `SparkApplication` CR) | Your laptop, an Airflow worker pod, a Kubeflow Notebook pod, or the Spark Operator controller itself |
| **Driver** | The process running your `main()`/`SparkContext`. Builds the DAG of stages/tasks, requests executors, and schedules tasks onto them | A single Kubernetes **Pod** |
| **Executor** | A JVM process that runs tasks assigned by the driver and reports results back | One **Pod** per executor, `spec.executor.instances` of them |
| **Cluster Manager** | Decides where pods get placed | The Kubernetes API server + the (native) kube-scheduler |

## Cluster mode vs client mode

- **`cluster` mode** (what we use throughout this tutorial, and what the
  Spark Operator always uses): the driver itself runs **inside the cluster**
  as a pod. You submit the job and walk away; the driver pod is the
  long-lived "conductor."
- **`client` mode**: the driver runs **outside** the cluster (e.g. in your
  terminal, or inside a Jupyter Notebook process). The driver still talks to
  the Kubernetes API to launch executor pods, but if the client process
  dies, the job dies with it. This is the mode you'll use in
  `docs/06-kubeflow-notebook-spark.md` for interactive exploration, because
  you want the driver's SparkContext alive in your notebook kernel so you
  can run cell-by-cell.

## Step-by-step lifecycle of a `SparkApplication`

Given [`manifests/spark-jobs/spark-pi.yaml`](../manifests/spark-jobs/spark-pi.yaml):

```
kubectl apply -f manifests/spark-jobs/spark-pi.yaml
```

1. **Admission & translation.** The Spark Operator's webhook validates the
   CR, then its controller translates the spec into an internal
   `spark-submit` command roughly equivalent to:

   ```bash
   spark-submit \
     --master k8s://https://<k8s-api-server>:443 \
     --deploy-mode cluster \
     --class org.apache.spark.examples.SparkPi \
     --conf spark.kubernetes.namespace=spark-jobs \
     --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark-driver \
     --conf spark.kubernetes.container.image=docker.io/apache/spark:3.5.1 \
     --conf spark.executor.instances=2 \
     --conf spark.driver.memory=512m \
     --conf spark.executor.memory=512m \
     local:///opt/spark/examples/jars/spark-examples_2.12-3.5.1.jar 1000
   ```

2. **Driver pod creation.** The operator (acting as the "client" in
   cluster-mode terms) asks the Kubernetes API to create a **driver Pod**
   named `spark-pi-driver`, running the `spark-submit`-equivalent entrypoint
   with the `spark-driver` ServiceAccount (needs RBAC to manage pods — see
   [`manifests/rbac/spark-rbac.yaml`](../manifests/rbac/spark-rbac.yaml)).

3. **Driver bootstraps `SparkContext`.** Inside the driver pod, your Spark
   application's `main()` runs, creating a `SparkSession`/`SparkContext`
   configured with `master=k8s://...`. Spark's own
   `KubernetesClusterManager` inside the driver now takes over.

4. **Driver creates a headless Service.** So executors can reach the driver
   back for task scheduling/shuffle metadata, Spark creates a headless
   Kubernetes `Service` (e.g. `spark-pi-<id>-driver-svc`) pointing at the
   driver pod.

5. **Driver requests executor pods.** Based on `spec.executor.instances`
   (2, in our example), the driver calls the Kubernetes API directly
   (using its ServiceAccount's RBAC permissions) to create N **executor
   Pods**. Each executor pod:
   - Runs the same container image as the driver (`apache/spark:3.5.1`).
   - Is passed the driver's pod IP/hostname and a unique executor ID via
     environment variables / Spark conf.
   - Registers back with the driver over the driver's Service once its JVM
     starts, sending a heartbeat.

6. **Task scheduling.** The driver's `DAGScheduler` splits your job into
   stages, and the `TaskScheduler` assigns individual tasks to registered
   executors based on data locality and available cores (each executor
   advertises `spark.executor.cores` worth of task slots).

7. **Shuffle & results.** Executors exchange shuffle data directly
   pod-to-pod (not through the driver). Final results/aggregations are sent
   back to the driver, which returns them to your application code (or, for
   `SparkPi`, just prints the estimated value of Pi to the driver pod's
   logs).

8. **Completion & cleanup.** Once the driver's `main()` returns, the driver
   pod's Spark context requests executor pod termination. The driver pod
   itself transitions to `Completed`. The Spark Operator watches the driver
   pod's terminal status and updates `SparkApplication.status.applicationState`
   to `COMPLETED` (or `FAILED`).

## Watching this happen live

```bash
kubectl apply -f manifests/spark-jobs/spark-pi.yaml
kubectl get sparkapplications -n spark-jobs -w
kubectl get pods -n spark-jobs -w
kubectl logs -n spark-jobs spark-pi-driver -f
```

You'll see, in order: the driver pod appear → 2 executor pods appear
shortly after → executor pods disappear once tasks finish → driver pod goes
`Completed` → `SparkApplication` status flips to `COMPLETED`.

## Why RBAC matters here

Unlike Spark-on-YARN (where the YARN ResourceManager launches containers on
the driver's behalf), on Kubernetes **the driver pod itself calls the
Kubernetes API** to create executor pods. That's why the `spark-driver`
ServiceAccount needs a `Role` granting `create`/`delete`/`watch` on `pods`
and `services` in its own namespace — see
[`manifests/rbac/spark-rbac.yaml`](../manifests/rbac/spark-rbac.yaml). Without
this, the driver pod starts but immediately fails with a `Forbidden` error
when it tries to launch executors.

## Native Kubernetes scheduling (no extra scheduler needed)

Every driver and executor pod above is scheduled onto a cluster node by the
**default kube-scheduler** — no additional scheduling software is required
to run Spark on Kubernetes/OpenShift. Pod placement uses standard mechanisms
you can layer on as needed: `resources.requests/limits`, `nodeSelector`,
`affinity`/`podAntiAffinity`, `tolerations`, and `PriorityClass`. This
tutorial relies entirely on the native scheduler; see
[`docs/05-running-spark-jobs.md`](05-running-spark-jobs.md) for the full
field reference on the SparkApplication spec.

## Next

→ [`docs/05-running-spark-jobs.md`](05-running-spark-jobs.md)
