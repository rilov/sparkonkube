#!/usr/bin/env bash
# Step 2: Install the Kubeflow Spark Operator via Helm.
# This installs the SparkApplication/ScheduledSparkApplication CRDs and the
# controller that watches for them and manages driver/executor pods.
set -euo pipefail

NAMESPACE="${SPARK_OPERATOR_NAMESPACE:-spark-operator}"
RELEASE="${SPARK_OPERATOR_RELEASE:-spark-operator}"

echo ">> Adding the spark-operator Helm repo..."
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update

echo ">> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing/upgrading the Spark Operator release '$RELEASE'..."
helm upgrade --install "$RELEASE" spark-operator/spark-operator \
  --namespace "$NAMESPACE" \
  -f "$(dirname "$0")/../manifests/spark-operator/values.yaml" \
  --wait

echo ">> Waiting for the operator pod to become Ready..."
kubectl -n "$NAMESPACE" rollout status deployment -l app.kubernetes.io/name=spark-operator --timeout=180s || true
kubectl -n "$NAMESPACE" get pods

echo ">> Verifying CRDs are registered..."
kubectl get crd | grep sparkoperator

echo ">> Applying RBAC for Spark drivers to manage executor pods..."
kubectl apply -f "$(dirname "$0")/../manifests/rbac/spark-rbac.yaml"

echo ">> Done. Next: ./scripts/03-install-argocd.sh"
