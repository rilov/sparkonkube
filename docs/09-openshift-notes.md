# Step 9: Moving from Minikube to Real OpenShift

Everything in `manifests/` is standard Kubernetes YAML and works on
OpenShift largely unmodified. Here are the adjustments you'll need.

## 1. CLI

Use `oc` instead of (or alongside) `kubectl` — they're wire-compatible:

```bash
oc login <cluster-api-url>
oc new-project spark-jobs
oc apply -f manifests/spark-jobs/spark-pi.yaml
```

## 2. Security Context Constraints (SCC)

OpenShift enforces SCCs by default, which are stricter than vanilla
Kubernetes PodSecurityPolicies. The Spark container images (`apache/spark`)
run as a fixed non-root UID by default, but OpenShift's `restricted` SCC
assigns a **random** UID per namespace. You have two options:

**Option A (recommended):** Build/use a Spark image compatible with
arbitrary UIDs (this is how Bitnami's and Red Hat's Spark images are built —
group `0` ownership + `g+rwx` permissions on Spark's directories).

**Option B:** Grant the `spark-driver` ServiceAccount the `anyuid` SCC
(only do this in dev/test):

```bash
oc adm policy add-scc-to-user anyuid -z spark-driver -n spark-jobs
```

## 3. Routes instead of Ingress

To expose ArgoCD, Airflow, or the Notebook UI externally instead of
port-forwarding, create an OpenShift `Route`:

```bash
oc create route edge argocd --service=argocd-server -n argocd --port=https
oc create route edge airflow --service=airflow-webserver -n airflow --port=8080
```

## 4. Image registry

Push the Spark/Airflow/notebook images to OpenShift's internal registry or
an accessible external one, and reference them with the full pull path if
your cluster restricts external registry access:

```bash
oc image mirror docker.io/apache/spark:3.5.1 \
  default-route-openshift-image-registry.apps.<cluster-domain>/spark-jobs/spark:3.5.1
```

## 5. Spark Operator Helm install on OpenShift

Same Helm command as Step 2, just make sure `helm`/`oc` are pointed at the
OpenShift cluster's context:

```bash
oc project spark-operator
helm upgrade --install spark-operator spark-operator/spark-operator \
  --namespace spark-operator -f manifests/spark-operator/values.yaml
```

If the operator's ServiceAccount needs elevated pod-management permissions
cluster-wide (watching all namespaces), you may need a `ClusterRole`/
`ClusterRoleBinding` rather than the namespaced `Role` used in
[`manifests/rbac/spark-rbac.yaml`](../manifests/rbac/spark-rbac.yaml) —
check the chart's own ClusterRole templates, which already handle this for
the operator's own ServiceAccount; the CR in this repo only concerns the
**driver/submitter** ServiceAccounts.

## 6. ArgoCD on OpenShift

Red Hat ships **OpenShift GitOps**, which is ArgoCD packaged as an
Operator via OperatorHub — install it that way instead of the raw manifests
used by `scripts/03-install-argocd.sh` for a fully supported experience:

```bash
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: latest
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

## Next

→ [`docs/10-troubleshooting.md`](10-troubleshooting.md)
