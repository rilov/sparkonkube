# Step 8: dbt + Spark (Optional)

If your pipeline includes SQL-based transformations, you can layer **dbt**
on top of the Spark jobs orchestrated by Airflow, using the
[`dbt-spark`](https://github.com/dbt-labs/dbt-spark) adapter.

## How dbt fits in

dbt does **not** submit `SparkApplication` CRs or manage driver/executor
pods itself — it needs a **live Spark endpoint** to send SQL to. On
Kubernetes, the common pattern is:

1. Run a long-lived Spark cluster with **Spark Thrift Server** (exposes a
   JDBC/ODBC endpoint backed by a persistent `SparkSession`), deployed as
   its own `SparkApplication` (`mode: cluster`, long-running driver).
2. Point `dbt-spark`'s `profiles.yml` at that Thrift Server endpoint.
3. Trigger `dbt run` as a downstream Airflow task, after upstream Spark ETL
   jobs land data dbt's models depend on.

## Example: long-running Thrift Server `SparkApplication`

```yaml
apiVersion: sparkoperator.k8s.io/v1beta2
kind: SparkApplication
metadata:
  name: spark-thrift-server
  namespace: spark-jobs
spec:
  type: Scala
  mode: cluster
  image: "docker.io/apache/spark:3.5.1"
  mainClass: org.apache.spark.sql.hive.thriftserver.HiveThriftServer2
  mainApplicationFile: "local:///opt/spark/jars/spark-hive-thriftserver_2.12-3.5.1.jar"
  sparkVersion: "3.5.1"
  restartPolicy:
    type: OnFailure
  driver:
    cores: 1
    memory: "1g"
    serviceAccount: spark-driver
  executor:
    cores: 1
    instances: 2
    memory: "1g"
```

Expose it with a `Service` so dbt can reach it at a stable address, e.g.
`spark-thrift-server.spark-jobs.svc.cluster.local:10000`.

## Example `profiles.yml` for `dbt-spark`

```yaml
my_spark_project:
  target: dev
  outputs:
    dev:
      type: spark
      method: thrift
      host: spark-thrift-server.spark-jobs.svc.cluster.local
      port: 10000
      schema: analytics
      threads: 4
```

## Wiring dbt into the Airflow DAG

Add a task after `monitor_spark_pi` (or your real ETL job) using either the
[`astronomer-cosmos`](https://astronomer.github.io/astronomer-cosmos/) package
(recommended, models become individual Airflow tasks) or a simple
`KubernetesPodOperator` running `dbt run` in a container with `dbt-spark`
installed:

```python
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator

run_dbt = KubernetesPodOperator(
    task_id="dbt_run",
    namespace="airflow",
    image="ghcr.io/dbt-labs/dbt-spark:1.7.1",
    cmds=["dbt", "run", "--profiles-dir", "/dbt/profiles", "--project-dir", "/dbt/project"],
    name="dbt-run-pod",
    get_logs=True,
)

monitor_spark_pi >> run_dbt
```

## Summary

| Component | Role |
|-----------|------|
| Spark Operator | Runs the long-lived Spark Thrift Server (and any batch ETL `SparkApplication`s) |
| Airflow | Orchestrates: ETL job → wait for completion → trigger dbt run → downstream tasks |
| dbt (`dbt-spark`) | Sends SQL transformations to the Thrift Server's live SparkSession |

This tutorial doesn't install dbt by default (it's workload-specific), but
the pieces above are enough to wire it into the same cluster and DAG
structure built in Steps 2–7.

## Next

→ [`docs/09-openshift-notes.md`](09-openshift-notes.md)
