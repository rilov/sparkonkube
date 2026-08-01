# Step 7: Orchestrating Spark with Apache Airflow

`ScheduledSparkApplication` (Step 5) handles simple cron-style repetition,
but real pipelines need an **external workflow scheduler** to express
dependencies across systems — e.g. "wait for an upstream ingestion job,
run Spark, then run dbt, then notify Slack, with retries/backfills/SLAs."
That's Airflow's job.

## Install Airflow

```bash
./scripts/05-install-airflow.sh
```

This script:

1. Installs the official `apache-airflow/airflow` Helm chart into the
   `airflow` namespace with the `KubernetesExecutor` (each Airflow task runs
   in its own ephemeral pod — consistent with how everything else in this
   tutorial runs on Kubernetes).
2. Mounts [`manifests/airflow/dags/spark_pi_dag.py`](../manifests/airflow/dags/spark_pi_dag.py)
   via a ConfigMap.
3. Applies RBAC so the `airflow-worker` ServiceAccount can create
   `SparkApplication` CRs in `spark-jobs`.

Port-forward and open the UI:

```bash
kubectl -n airflow port-forward svc/airflow-webserver 8081:8080
```

Browse `http://localhost:8081` (user: `admin`, password: `admin`).

## Install the required Airflow provider

The DAG uses `SparkKubernetesOperator`/`SparkKubernetesSensor` from the
CNCF Kubernetes provider. Add it to your Airflow image (or, for a quick
test, `pip install` it into the scheduler/worker pods):

```
apache-airflow-providers-cncf-kubernetes>=7.0.0
```

In a production setup, bake this into a custom Airflow image referenced by
`manifests/airflow/values.yaml`'s `images.airflow.repository`/`tag`.

## The example DAG

[`manifests/airflow/dags/spark_pi_dag.py`](../manifests/airflow/dags/spark_pi_dag.py):

```python
submit_spark_pi = SparkKubernetesOperator(
    task_id="submit_spark_pi",
    namespace="spark-jobs",
    application_file="spark-pi.yaml",
    kubernetes_conn_id="kubernetes_default",
    do_xcom_push=True,
)

monitor_spark_pi = SparkKubernetesSensor(
    task_id="monitor_spark_pi",
    namespace="spark-jobs",
    application_name="{{ task_instance.xcom_pull(task_ids='submit_spark_pi')['metadata']['name'] }}",
    kubernetes_conn_id="kubernetes_default",
)

submit_spark_pi >> monitor_spark_pi
```

- `SparkKubernetesOperator` applies the `SparkApplication` CR
  ([`manifests/airflow/dags/spark-pi.yaml`](../manifests/airflow/dags/spark-pi.yaml),
  bundled next to the DAG) to the cluster — this is the **same CRD** the
  Spark Operator watches, so Airflow is just another *submitter*, exactly
  like `kubectl apply` or the Kubeflow Notebook in Step 6.
- `SparkKubernetesSensor` polls the `SparkApplication`'s `.status` field
  until it reaches a terminal state, surfacing success/failure back to
  Airflow's UI, retry logic, and alerting.

## Why this division of responsibility matters

| Layer | Responsibility |
|-------|-----------------|
| **Airflow** | *When* to run, *in what order*, cross-system dependencies, retries, backfills, alerting |
| **Spark Operator** | *How* to run a Spark job on Kubernetes — translating a declarative spec into driver/executor pods |
| **Kubernetes scheduler** | *Where* each pod physically lands on a node |

Airflow never talks to the Spark driver/executor pods directly — it only
manages the `SparkApplication` **custom resource's lifecycle**, keeping the
concerns cleanly separated (this is also why the Spark Operator approach
works identically whether the CR was submitted by Airflow, by a notebook,
or by ArgoCD).

## Trigger the DAG

```bash
# via UI: toggle "spark_pi_via_spark_operator" on, then click "Trigger DAG"
# via CLI (from a scheduler/worker pod, or with the airflow CLI locally):
kubectl exec -n airflow deploy/airflow-scheduler -- \
  airflow dags trigger spark_pi_via_spark_operator
```

Watch it run:

```bash
kubectl get sparkapplications -n spark-jobs -w
```

## Next

→ [`docs/08-dbt-spark-integration.md`](08-dbt-spark-integration.md)
