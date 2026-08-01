# Step 0: Prerequisites

## Hardware / OS

- macOS or Linux, 8GB+ free RAM, 4+ CPU cores free for the VM/containers.
- Docker Desktop (macOS) or Docker Engine (Linux) installed and running.

## CLI tools

| Tool | Purpose |
|------|---------|
| `kubectl` | Talk to the Kubernetes API server |
| `helm` | Install the Spark Operator and Airflow charts |
| `minikube` | Run a local, single-node Kubernetes cluster that mimics OpenShift |

Run the installer script:

```bash
./scripts/00-install-cli-tools.sh
```

This uses Homebrew on macOS. On Linux, install manually:

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

Verify:

```bash
kubectl version --client
helm version
minikube version
docker version
```

## Why Minikube instead of OpenShift directly?

OpenShift is a certified, enterprise Kubernetes distribution — everything we
do here (CRDs, Helm charts, RBAC, ArgoCD Applications, SparkApplication
resources) is **standard Kubernetes API objects** and works unmodified on
OpenShift. Minikube lets you learn and iterate quickly and for free on a
laptop. `docs/09-openshift-notes.md` lists the handful of OpenShift-specific
adjustments (Security Context Constraints, `oc` vs `kubectl`, routes vs
ingress) you'll need when you move to a real OpenShift cluster.

## Next

→ [`docs/01-minikube-setup.md`](01-minikube-setup.md)
