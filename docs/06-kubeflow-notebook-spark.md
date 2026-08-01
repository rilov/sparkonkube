# Step 6: Running Spark from a Kubeflow Notebook

Data scientists typically want to iterate on Spark code cell-by-cell rather
than package a jar/py file and wait for a full `SparkApplication` run. This
step shows two ways to do that from a Kubeflow Notebook.

## Install the Notebook Controller + sample notebook

```bash
./scripts/04-install-kubeflow-notebook.sh
```

This installs the lightweight Kubeflow **Notebook Controller** (just the
notebooks component, not the full Kubeflow platform) and applies
[`manifests/notebook/spark-notebook.yaml`](../manifests/notebook/spark-notebook.yaml),
a `Notebook` CR using the `jupyter/pyspark-notebook:spark-3.5.1` image
(Spark + PySpark pre-installed).

Port-forward and open it:

```bash
kubectl -n kubeflow port-forward svc/spark-notebook 8888:80
```

Browse `http://localhost:8888`.

## Option A — Client-mode PySpark session (fastest for interactive EDA)

Inside a notebook cell:

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("notebook-interactive-spark")
    .master("k8s://https://kubernetes.default.svc:443")
    .config("spark.submit.deployMode", "client")
    .config("spark.kubernetes.namespace", "kubeflow")
    .config("spark.kubernetes.authenticate.driver.serviceAccountName", "default")
    .config("spark.kubernetes.container.image", "apache/spark:3.5.1")
    .config("spark.executor.instances", "2")
    .config("spark.executor.memory", "1g")
    .config("spark.driver.host", "spark-notebook.kubeflow.svc.cluster.local")
    .getOrCreate()
)

df = spark.range(1000000)
print(df.selectExpr("sum(id)").collect())
```

Here, the **driver runs inside your notebook's Python kernel process**
(client mode — see `docs/04-spark-architecture.md`), and Spark itself
creates the **executor pods** in the `kubeflow` namespace via the
Kubernetes API, using the notebook pod's ServiceAccount (RBAC granted by
[`manifests/rbac/spark-rbac.yaml`](../manifests/rbac/spark-rbac.yaml)).

Important: `spark.driver.host` must resolve to the notebook pod itself, so
that executors can call back into your kernel process. Because notebooks
run as a `StatefulSet`/`Deployment` with a stable Service name
(`spark-notebook.kubeflow.svc.cluster.local`), this works reliably.

Stop the session (and the executor pods it created) when done:

```python
spark.stop()
```

## Option B — Submit a full `SparkApplication` CR from the notebook

For heavier or production-style jobs, use the notebook purely to
**generate and submit** a `SparkApplication` CR (cluster mode, driver runs
as its own pod, independent of the notebook kernel):

```python
from kubernetes import client, config

config.load_incluster_config()
api = client.CustomObjectsApi()

spark_app = {
    "apiVersion": "sparkoperator.k8s.io/v1beta2",
    "kind": "SparkApplication",
    "metadata": {"name": "notebook-submitted-job", "namespace": "spark-jobs"},
    "spec": {
        "type": "Python",
        "mode": "cluster",
        "image": "docker.io/apache/spark:3.5.1",
        "mainApplicationFile": "local:///opt/spark/examples/src/main/python/pi.py",
        "sparkVersion": "3.5.1",
        "restartPolicy": {"type": "Never"},
        "driver": {"cores": 1, "memory": "512m", "serviceAccount": "spark-driver"},
        "executor": {"cores": 1, "instances": 2, "memory": "512m"},
    },
}

api.create_namespaced_custom_object(
    group="sparkoperator.k8s.io",
    version="v1beta2",
    namespace="spark-jobs",
    plural="sparkapplications",
    body=spark_app,
)
```

This requires the `kubernetes` Python package (`pip install kubernetes`,
already present in the `jupyter/pyspark-notebook` image family or install it
via a cell) and RBAC for the notebook's ServiceAccount to create
`SparkApplication` objects in `spark-jobs` — already granted by
[`manifests/rbac/spark-rbac.yaml`](../manifests/rbac/spark-rbac.yaml)
(`spark-submitter-rolebinding` includes the `default` ServiceAccount in the
`kubeflow` namespace).

## When to use which option

| Use case | Option |
|----------|--------|
| Fast interactive EDA, small data, tight feedback loop | A (client mode) |
| Heavier ETL, want driver isolated from the notebook's lifecycle, want it visible in ArgoCD/GitOps | B (SparkApplication CR) |
| Job needs to survive after you close the notebook tab | B |

## Next

→ [`docs/07-airflow-orchestration.md`](07-airflow-orchestration.md)
