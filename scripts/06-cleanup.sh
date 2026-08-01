#!/usr/bin/env bash
# Cleanup: tear down everything created by this tutorial.
set -euo pipefail

PROFILE="${MINIKUBE_PROFILE:-spark-on-k8s}"

read -r -p "This will delete the minikube profile '$PROFILE' and all workloads. Continue? [y/N] " ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

minikube delete -p "$PROFILE"
echo ">> Minikube profile '$PROFILE' deleted."
