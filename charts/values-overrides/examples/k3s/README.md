# Deploy Graphistry on k3s

This guide provides step-by-step instructions for deploying Graphistry on k3s, a lightweight Kubernetes distribution.

## Prerequisites

### k3s Cluster
- A running k3s cluster with GPU nodes
- `kubectl` configured to access the cluster (or use `k3s kubectl`)
- Helm 3.x installed

### Install k3s
```bash
curl -sfL https://get.k3s.io | sh -
```

If you don't have `kubectl` set up, alias it:
```bash
alias kubectl='k3s kubectl'
```

### Verify Cluster Access
```bash
kubectl get nodes -o wide
```

## Setup NVIDIA Container Runtime

Verify that the container runtime supports NVIDIA GPUs:
```bash
apt-get install nvidia-container-runtime
```

Edit the k3s service to use NVIDIA runtime:
```bash
nano /etc/systemd/system/k3s.service
```

Add `--default-runtime nvidia` to the ExecStart command:
```bash
ExecStart=/usr/local/bin/k3s \
    server --default-runtime nvidia
```

Restart k3s:
```bash
systemctl daemon-reload
systemctl restart k3s
```

## Install NVIDIA GPU Support

### Option 1: NVIDIA GPU Operator (Recommended)
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update

kubectl create ns gpu-operator

helm install --wait --generate-name \
    -n gpu-operator nvidia/gpu-operator \
    --set driver.version="<DRIVER_VERSION>" \
    --timeout 60m
```

Graphistry publishes Docker images for both CUDA 12.8 and CUDA 11.8. The `cuda.version` chart value selects which image variant to pull (e.g., `graphistry/nexus:v2.45.11-12.8`). The GPU driver must be compatible with the chosen CUDA version:

| CUDA Version | Minimum Driver | Recommended `driver.version` | Notes |
|---|---|---|---|
| 12.8 | >=570.26 | `570.195.03` | R570 branch or newer |
| 11.8 | >=520.61.05 | `535.288.01` | R535 branch or newer |

The chart default is `cuda.version: "12.8"`. If using CUDA 11.8, add `--set cuda.version="11.8"` to your Graphistry helm install command (the [Install Graphistry](#install-graphistry) step, not the GPU Operator). See the [NVIDIA CUDA Toolkit Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/) for the full driver compatibility matrix.

Wait for the operator pods to be ready:
```bash
kubectl get pods -n gpu-operator --watch
```

### Option 2: NVIDIA Device Plugin
If NVIDIA drivers are already installed on your nodes:
```bash
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml
```

### Verify GPU Access
```bash
kubectl get nodes -ojson | jq '.items[].status.capacity | select(.["nvidia.com/gpu"] != null)'
```

## Create Graphistry Namespace and Secrets

### Create Namespace
```bash
kubectl create namespace graphistry
```

### Create Docker Hub Secret
Your Docker Hub account must have access to Graphistry images:
```bash
kubectl create secret docker-registry docker-secret-prod \
    --namespace graphistry \
    --docker-server=docker.io \
    --docker-username=<YOUR_DOCKERHUB_USER> \
    --docker-password=<YOUR_DOCKERHUB_TOKEN>
```

### Create GAK Secret (Optional)
For [Graph App Kit](https://github.com/graphistry/graph-app-kit) dashboards:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gak-secret
  namespace: graphistry
type: Opaque
stringData:
  username: graphistry_user
  password: graphistry_password
EOF
```

## Get Graphistry Helm Charts

```bash
git clone https://github.com/graphistry/graphistry-helm
cd graphistry-helm
```

Run the chart bundler:
```bash
bash chart-bundler/bundler.sh
```

## Install Kubernetes Operators

### Install Postgres Operator

Install [PGO](https://access.crunchydata.com/documentation/postgres-operator/latest/installation/helm) (Crunchy Postgres Operator):
```bash
helm install pgo ./charts-aux-bundled/pgo \
    --namespace postgres-operator --create-namespace
```

Wait for the operator:
```bash
kubectl get pods --watch --namespace postgres-operator
```

### Install Dask Operator
```bash
cd charts-aux-bundled/dask-kubernetes-operator/ && helm dep build && cd ../..

helm upgrade -i dask-operator ./charts-aux-bundled/dask-kubernetes-operator \
    --namespace dask-operator --create-namespace
```

## Install Postgres Cluster

```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster \
    --namespace graphistry --create-namespace
```

Verify the pods are created (both will be `Pending` until `graphistry-resources` creates the required storage classes in a later step):
```bash
kubectl get pods -n graphistry
```

**Note**: Both postgres pods will stay in `Pending` state. They require storage classes (`retain-sc` and `retain-sc-<namespace>`) which are created by `graphistry-resources` in the next step.

## Install Graphistry Resources

View available values:
```bash
helm show values ./charts/graphistry-helm-resources
```

Install the graphistry-resources chart using this command:
```bash
helm upgrade -i graphistry-resources ./charts/graphistry-helm-resources \
    --set global.provisioner="rancher.io/local-path" \
    --namespace graphistry --create-namespace
```

This chart creates the required storage classes using your provisioner (`rancher.io/local-path`).

### Storage Classes Created

| Storage Class | reclaimPolicy | Description |
|---------------|---------------|-------------|
| `retain-sc` | Retain | Data preserved when PVC deleted (manual cleanup required) |
| `retain-sc-<namespace>` | Retain | Namespace-scoped retain class for postgres backup repo isolation |
| `uploadfiles-sc` | Delete | Data deleted when PVC deleted |

### PVCs and Services (graphistry-helm chart)

| PVC | Storage Class | Used By Services |
|-----|---------------|------------------|
| `data-mount` | retain-sc | nexus, nginx, forge-etl-python, streamgl-gpu, streamgl-viz, streamgl-sessions, dask-scheduler, dask-cuda-worker, redis, pivot, caddy, notebook |
| `local-media-mount` | retain-sc | nexus, nginx |
| `gak-public` | retain-sc | graph-app-kit-public, notebook |
| `gak-private` | retain-sc | graph-app-kit-private, notebook |
| `uploads-files` | uploadfiles-sc | nginx, forge-etl-python |

### Postgres Storage (postgres-cluster chart)

The `postgres-cluster` chart creates a `PostgresCluster` CR. The PGO operator dynamically provisions PVCs using:
- Instance data volume on `retain-sc` (e.g., `postgres-instance1-xxxx-0`)
- Backup repository volume on `retain-sc-<namespace>` for multi-tenant isolation

Wait for resources (the `postgres-instance` pod should now start running):
```bash
kubectl get pods --watch -n graphistry
```

## Install Graphistry

Using the k3s-specific values file:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/k3s/k3s_example_values.yaml \
    --namespace graphistry --create-namespace
```

Wait for all pods to be running:
```bash
kubectl get pods --watch -n graphistry
```

## Access Graphistry

Get the service address:
```bash
kubectl get services -n graphistry | grep caddy
```

For k3s with Traefik ingress:
```bash
kubectl get ingress -n graphistry
```

## Update Graphistry Deployment

When updating, preserve existing volume bindings:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/k3s/k3s_example_values.yaml \
    --set volumeName.dataMount=$(kubectl get pv -n graphistry | grep "data-mount" | tail -n 1 | awk '{print $1;}') \
    --set volumeName.localMediaMount=$(kubectl get pv -n graphistry | grep "local-media-mount" | tail -n 1 | awk '{print $1;}') \
    --set volumeName.gakPublic=$(kubectl get pv -n graphistry | grep "gak-public" | tail -n 1 | awk '{print $1;}') \
    --set volumeName.gakPrivate=$(kubectl get pv -n graphistry | grep "gak-private" | tail -n 1 | awk '{print $1;}') \
    --namespace graphistry --create-namespace
```

## Enabling Telemetry

Telemetry is enabled by default (`ENABLE_OPEN_TELEMETRY: true`). For configuration options, see the [Graphistry Kubernetes Telemetry Documentation](https://graphistry-admin-docs.readthedocs.io/en/latest/telemetry/kubernetes.html).

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n graphistry
kubectl describe pod <pod-name> -n graphistry
```

### Check Logs
```bash
# Nexus logs
kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep nexus) -f

# forge-etl-python logs
kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep forge-etl-python) -f

# nginx logs
kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep nginx) -f
```

### Check PVC Status
```bash
kubectl get pvc -n graphistry
```

### GPU Issues
```bash
# Check GPU operator status
kubectl get pods -n gpu-operator

# Check GPU availability on nodes
kubectl describe node <node-name> | grep -A 5 "Capacity:"
```

## Cleanup

```bash
# Uninstall Graphistry
helm uninstall g-chart -n graphistry

# Uninstall resources
helm uninstall graphistry-resources -n graphistry
helm uninstall postgres-cluster -n graphistry

# Uninstall operators
helm uninstall pgo -n postgres-operator
helm uninstall dask-operator -n dask-operator

# Uninstall GPU Operator (--generate-name creates a dynamic release name)
helm list -n gpu-operator -q | xargs -I {} helm uninstall {} -n gpu-operator

# Delete namespaces
kubectl delete namespace graphistry
kubectl delete namespace postgres-operator
kubectl delete namespace dask-operator
kubectl delete namespace gpu-operator
```

## References

- [k3s Documentation](https://docs.k3s.io/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
- [Graphistry Admin Docs](https://graphistry-admin-docs.readthedocs.io/)
