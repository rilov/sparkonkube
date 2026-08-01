#!/usr/bin/env bash
# Step 5 (optional): Install Apache Airflow via the official Helm chart to
# act as the external workflow scheduler that triggers SparkApplication CRs
# on a schedule (and can call dbt as a downstream task).
set -euo pipefail

NAMESPACE="${AIRFLOW_NAMESPACE:-airflow}"
RELEASE="${AIRFLOW_RELEASE:-airflow}"

echo ">> Adding the apache-airflow Helm repo..."
helm repo add apache-airflow https://airflow.apache.org
helm repo update

echo ">> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Creating a ConfigMap with our example DAG..."
kubectl -n "$NAMESPACE" create configmap airflow-dags \
  --from-file="$(dirname "$0")/../manifests/airflow/dags" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing/upgrading Airflow release '$RELEASE'..."
helm upgrade --install "$RELEASE" apache-airflow/airflow \
  --namespace "$NAMESPACE" \
  -f "$(dirname "$0")/../manifests/airflow/values.yaml" \
  --wait --timeout 10m

echo ">> Applying RBAC so the Airflow worker SA can submit SparkApplication CRs..."
kubectl apply -f "$(dirname "$0")/../manifests/rbac/spark-rbac.yaml"

echo ">> Port-forward the Airflow UI with:"
echo "   kubectl -n $NAMESPACE port-forward svc/airflow-webserver 8081:8080"
echo "   then browse http://localhost:8081 (user: admin / pass: admin)"

echo ">> Done. Next: read docs/07-airflow-orchestration.md"
