#!/usr/bin/env bash
# Step 0: Install the CLI tools needed for this tutorial.
# macOS uses Homebrew. For Linux, see the commented alternatives below.
set -euo pipefail

echo ">> Checking/installing kubectl, helm, minikube..."

if ! command -v brew &>/dev/null; then
  echo "Homebrew not found. Install it from https://brew.sh first (macOS),"
  echo "or on Linux install each tool manually:"
  echo "  kubectl : https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
  echo "  helm    : https://helm.sh/docs/intro/install/"
  echo "  minikube: https://minikube.sigs.k8s.io/docs/start/"
  exit 1
fi

brew list kubectl  &>/dev/null || brew install kubectl
brew list helm     &>/dev/null || brew install helm
brew list minikube &>/dev/null || brew install minikube

echo ">> Versions installed:"
kubectl version --client --short 2>/dev/null || kubectl version --client
helm version --short
minikube version

echo ">> Done. Next: ./scripts/01-start-minikube.sh"
