#!/usr/bin/env bash
# Step 3: Install ArgoCD and register the Spark Operator + Spark job
# manifests as GitOps-managed Applications.
set -euo pipefail

NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"

echo ">> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo ">> Installing ArgoCD (official stable manifests)..."
kubectl apply -n "$NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ">> Waiting for ArgoCD server to become Ready (this can take a few minutes)..."
kubectl -n "$NAMESPACE" rollout status deployment/argocd-server --timeout=300s

echo ">> Fetching initial admin password..."
ARGOCD_PWD=$(kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "   ArgoCD admin password: $ARGOCD_PWD"
echo "   (Username: admin)"

echo ">> Port-forward the ArgoCD UI in another terminal with:"
echo "   kubectl -n $NAMESPACE port-forward svc/argocd-server 8080:443"
echo "   then browse https://localhost:8080"

echo ">> Registering the Spark Operator ArgoCD Application..."
kubectl apply -f "$(dirname "$0")/../manifests/argocd/applications/spark-operator-app.yaml"

echo ">> Registering the Spark Jobs ArgoCD Application..."
kubectl apply -f "$(dirname "$0")/../manifests/argocd/applications/spark-jobs-app.yaml"

echo ">> Done. Next: ./scripts/04-install-kubeflow-notebook.sh"
