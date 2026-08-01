# Step 5: Running Spark Jobs

## Submit the Scala example (SparkPi)

```bash
kubectl apply -f manifests/spark-jobs/spark-pi.yaml
kubectl get sparkapplications -n spark-jobs -w
```

Wait for `STATE` to reach `COMPLETED`, then read the driver's output:

```bash
kubectl logs -n spark-jobs spark-pi-driver | grep "Pi is roughly"
```

## Submit the Python example (PySpark)

```bash
kubectl apply -f manifests/spark-jobs/spark-pi-python.yaml
kubectl get sparkapplications -n spark-jobs -w
kubectl logs -n spark-jobs spark-pi-python-driver | grep "Pi is roughly"
```

## Anatomy of a `SparkApplication` spec

```yaml
spec:
  type: Scala | Python | Java | R
  mode: cluster            # always "cluster" for the operator
  image: <container image with Spark installed>
  mainClass: <fully qualified class, Scala/Java only>
  mainApplicationFile: <local:// or s3a:// or https:// path to jar/py file>
  arguments: [...]          # argv passed to your application
  sparkVersion: "3.5.1"
  driver:
    cores: 1
    memory: "512m"
    serviceAccount: spark-driver   # MUST have RBAC to manage pods (Step 4)
  executor:
    cores: 1
    instances: 2
    memory: "512m"
```

Common additions you'll want in real workloads:

```yaml
  driver:
    ...
    volumeMounts: [...]      # mount ConfigMaps/PVCs for config or data
    env:
      - name: MY_ENV
        value: "..."
  executor:
    ...
    instances: 4
  deps:
    jars: ["https://.../my-dependency.jar"]
    pyFiles: ["s3a://bucket/my_module.py"]
  hadoopConf:
    "fs.s3a.endpoint": "..."   # for reading/writing S3-compatible storage
```

## Cron-scheduled jobs without an external scheduler

For simple, fixed-interval jobs that don't need cross-system dependencies
(e.g. "run every 15 minutes, no matter what"), the Spark Operator provides
its own `ScheduledSparkApplication` CRD — no Airflow needed:

```bash
kubectl apply -f manifests/spark-jobs/spark-pi-scheduled.yaml
kubectl get scheduledsparkapplications -n spark-jobs
kubectl get sparkapplications -n spark-jobs   # one child SparkApplication per run
```

This is a Kubernetes-native cron, comparable to a `CronJob`. Reach for
Airflow (`docs/07-airflow-orchestration.md`) instead when you need:
task **dependencies** across systems (e.g. "run dbt only after this Spark
job succeeds, then trigger a Slack alert"), **backfills**, **SLA
monitoring**, or a UI showing historical DAG runs.

## Deleting / re-running a job

`SparkApplication` names must be unique per apply. To re-run:

```bash
kubectl delete sparkapplication spark-pi -n spark-jobs
kubectl apply -f manifests/spark-jobs/spark-pi.yaml
```

## Next

→ [`docs/06-kubeflow-notebook-spark.md`](06-kubeflow-notebook-spark.md) to
run Spark interactively, or skip to
[`docs/07-airflow-orchestration.md`](07-airflow-orchestration.md) for
scheduled orchestration.
