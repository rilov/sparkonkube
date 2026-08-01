#!/usr/bin/env bash
# Step 1: Start a local Kubernetes cluster with Minikube sized for
# Spark Operator + ArgoCD + Airflow + a notebook, all running concurrently.
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-spark-on-k8s}"
CPUS="${MINIKUBE_CPUS:-6}"
MEMORY="${MINIKUBE_MEMORY:-10240}"   # MB
DRIVER="${MINIKUBE_DRIVER:-docker}"

echo ">> Starting minikube profile '$PROFILE' (cpus=$CPUS memory=${MEMORY}MB driver=$DRIVER)..."
minikube start \
  -p "$PROFILE" \
  --cpus "$CPUS" \
  --memory "$MEMORY" \
  --driver "$DRIVER" \
  --kubernetes-version=stable

echo ">> Enabling addons: metrics-server, dashboard, ingress..."
minikube -p "$PROFILE" addons enable metrics-server
minikube -p "$PROFILE" addons enable dashboard
minikube -p "$PROFILE" addons enable ingress

echo ">> Creating a dedicated namespace for Spark workloads..."
kubectl create namespace spark-jobs --dry-run=client -o yaml | kubectl apply -f -

echo ">> Cluster info:"
kubectl cluster-info
kubectl get nodes -o wide

echo ">> Done. Next: ./scripts/02-install-spark-operator.sh"
