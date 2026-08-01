#!/usr/bin/env bash
# Step 4 (optional): Install the Kubeflow Notebook Controller so you can spin
# up a Jupyter Notebook custom resource and run PySpark interactively against
# the Spark Operator / Kubernetes cluster.
#
# We install just the "notebooks" component of Kubeflow (not the full
# Kubeflow platform) to keep the footprint small on Minikube.
set -euo pipefail

NAMESPACE="${KUBEFLOW_NAMESPACE:-kubeflow}"
NOTEBOOK_CTRL_VERSION="${NOTEBOOK_CTRL_VERSION:-v1.9.0}"

echo ">> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing the Notebook Controller CRDs + controller ($NOTEBOOK_CTRL_VERSION)..."
kubectl apply -k "github.com/kubeflow/kubeflow/components/notebook-controller/config/crd?ref=${NOTEBOOK_CTRL_VERSION}"
kubectl apply -k "github.com/kubeflow/kubeflow/components/notebook-controller/config/overlays/kubeflow?ref=${NOTEBOOK_CTRL_VERSION}" -n "$NAMESPACE"

echo ">> Waiting for notebook-controller to become Ready..."
kubectl -n "$NAMESPACE" rollout status deployment/notebook-controller-deployment --timeout=180s || true

echo ">> Applying RBAC so notebooks can submit SparkApplication CRs..."
kubectl apply -f "$(dirname "$0")/../manifests/rbac/spark-rbac.yaml"

echo ">> Creating the sample Spark Notebook..."
kubectl apply -f "$(dirname "$0")/../manifests/notebook/spark-notebook.yaml"

echo ">> Waiting for the notebook pod to become Ready..."
kubectl -n "$NAMESPACE" wait --for=condition=Ready pod -l notebook-name=spark-notebook --timeout=300s || true

echo ">> Port-forward the Notebook UI with:"
echo "   kubectl -n $NAMESPACE port-forward svc/spark-notebook 8888:80"
echo "   then browse http://localhost:8888"

echo ">> Done. Next: ./scripts/05-install-airflow.sh"
