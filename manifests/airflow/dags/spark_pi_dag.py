"""
Example Airflow DAG that submits a SparkApplication custom resource to the
Kubeflow Spark Operator and waits for it to complete. This is the external
"workflow scheduler" pattern discussed in docs/07-airflow-orchestration.md,
as opposed to Kubernetes-level pod scheduling.

Requires: apache-airflow-providers-cncf-kubernetes >= 7.0.0
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.spark_kubernetes import (
    SparkKubernetesOperator,
)
from airflow.providers.cncf.kubernetes.sensors.spark_kubernetes import (
    SparkKubernetesSensor,
)

default_args = {
    "owner": "data-platform",
    "retries": 1,
    "retry_delay": timedelta(minutes=2),
}

with DAG(
    dag_id="spark_pi_via_spark_operator",
    description="Submit spark-pi SparkApplication CR and monitor it to completion",
    default_args=default_args,
    schedule_interval="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["spark", "spark-operator", "example"],
) as dag:

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
