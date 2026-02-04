# Deploy Graphistry on VMware Tanzu Kubernetes Grid (TKG)

This guide provides step-by-step instructions for deploying Graphistry on VMware Tanzu Kubernetes Grid. The steps are based on the [Graphistry Helm Charts](https://github.com/graphistry/graphistry-helm) and adapted for Tanzu's vSphere CSI storage.

## Understanding the Tanzu/vSphere Architecture

### What is vSphere Infrastructure?

VMware vSphere is the virtualization platform that underlies Tanzu Kubernetes Grid:

```
Physical Servers (Bare Metal)
    |
    +-- ESXi Hypervisor (VMware's virtualization layer)
        |
        +-- vCenter Server (Management plane)
            |
            +-- Virtual Machines (VMs)
                |
                +-- Tanzu Kubernetes Grid (K8s running inside VMs)
                    |
                    +-- Pods (Graphistry containers)
```

Key components:
- **ESXi**: The hypervisor installed on physical servers
- **vCenter**: Central management for all ESXi hosts
- **vSAN/VMFS**: Storage systems that provide VMDKs (virtual disks)
- **NSX-T**: Software-defined networking (optional but common in enterprise)
- **vSphere CSI**: Storage driver that provisions VMDKs as Kubernetes PersistentVolumes

### Networking Architecture

Graphistry uses a multi-layer proxy architecture for handling traffic:

```
Internet/Corporate Network
        |
        v
+-------------------------------------------------------+
|  Kubernetes Ingress Controller (NGINX)                |
|  - Listens on LoadBalancer or NodePort                |
|  - Routes based on hostname/path                      |
|  - Session affinity via cookies (important for viz)   |
|  - Configured via: ingress.management.annotations     |
+-------------------------------------------------------+
        |
        v (routes to caddy:80)
+-------------------------------------------------------+
|  Caddy Pod (graphistry/caddy)                         |
|  - Optional SSL termination (if tls=true)             |
|  - Health endpoint: /caddy/health/                    |
|  - Reverse proxy to internal nginx                    |
+-------------------------------------------------------+
        |
        v
+-------------------------------------------------------+
|  Nginx Pod (internal service routing)                 |
|  - /api/v1/etl/ -> forge-etl-python                   |
|  - /graph/ -> streamgl-gpu                            |
|  - /pivot/ -> pivot                                   |
|  - Static files and API routing                       |
+-------------------------------------------------------+
        |
        v
+-------------------------------------------------------+
|  Backend Services                                     |
|  nexus, forge-etl-python, streamgl-gpu, pivot, etc.   |
+-------------------------------------------------------+
```

### Key Networking Configuration

The `tanzu_example_values.yaml` configures:

```yaml
global:
  ingressClassName: nginx          # Must match your ingress controller

ingress:
  management:
    annotations:
      kubernetes.io/ingress.class: nginx  # Legacy annotation for older K8s
```

Important settings in the Helm chart:
- **Session affinity**: Required for WebSocket connections to streamgl-gpu
- **Proxy body size**: Set to 20GB for large graph uploads (configurable via `ProxyBodySize`)
- **TLS**: Optional, can use cert-manager with Let's Encrypt

## Prerequisites

### Tanzu Kubernetes Cluster
- A running TKG cluster with GPU nodes (e.g., NVIDIA A40, T4, etc.)
- `kubectl` configured to access the cluster
- Helm 3.x installed

### Verify Cluster Access
```bash
kubectl get nodes -o wide
```

### Verify GPU Node
Ensure your cluster has GPU-enabled nodes:
```bash
kubectl get nodes --show-labels | grep -i gpu
```

## Storage Configuration

Tanzu uses the vSphere CSI driver with provisioner `csi.vsphere.vmware.com`. This is pre-installed on TKG clusters.

### Verify vSphere CSI Driver
```bash
kubectl get storageclass
```

You should see a storage class with `csi.vsphere.vmware.com` provisioner. Common names include `default`, `gc-storage-profile`, or a custom name defined by your vSphere admin.

## Install NVIDIA GPU Support

### Option 1: NVIDIA GPU Operator (Recommended)
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update

kubectl create ns gpu-operator

helm install --wait --generate-name \
    -n gpu-operator \
    nvidia/gpu-operator \
    --set driver.enabled=true \
    --set driver.version="550.127.08" \
    --timeout 60m
```

Wait for the operator pods to be ready:
```bash
kubectl get pods -n gpu-operator --watch
```

### Option 2: NVIDIA Device Plugin (If drivers pre-installed on nodes)
If NVIDIA drivers are already installed on your Tanzu nodes:
```bash
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml
```

### Verify GPU Access
```bash
kubectl get nodes -ojson | jq '.items[].status.capacity | select(.["nvidia.com/gpu"] != null)'
```

Expected output:
```json
{
  "nvidia.com/gpu": "1"
}
```

## Create Graphistry Namespace and Secrets

### Create Namespace
```bash
kubectl create namespace graphistry
```

### Create Docker Hub Secret
Your Docker Hub account must have access to Graphistry images (contact Graphistry support):
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

### Verify Secrets
```bash
kubectl get secret -n graphistry
```

## Air-Gapped / Offline Deployment

For environments with limited or no internet access, update your values file:

```yaml
global:
  # Redirect image pulls to your private registry
  # Images are pulled as: <containerregistry.name>/<image>:<tag>
  # Default: docker.io/graphistry (e.g., docker.io/graphistry/nexus:v2.45.11)
  # Air-gapped: my-registry.local/graphistry (e.g., my-registry.local/graphistry/nexus:v2.45.11)
  containerregistry:
    name: my-private-registry.local/graphistry

env:
  # Disables update checks and external API calls
  - name: AIR_GAPPED
    value: "1"
```

You must mirror all Graphistry images to your private registry before deployment. Contact Graphistry support for the complete image list for your version.

## Get Graphistry Helm Charts

```bash
git clone https://github.com/graphistry/graphistry-helm
cd graphistry-helm
```

Run the chart bundler to prepare dependencies:
```bash
bash chart-bundler/bundler.sh
```

## Install NGINX Ingress Controller

Tanzu does not include an ingress controller by default. NGINX Ingress Controller is recommended for Graphistry because it supports session affinity (required for WebSocket connections).

```bash
helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer
```

Wait for the external IP:
```bash
kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch
```

**Note**: If your Tanzu cluster doesn't support LoadBalancer services (no NSX-T or MetalLB), use NodePort instead:
```bash
helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=NodePort
```
Then access Graphistry via `http://<node-ip>:<node-port>`.

## Install Kubernetes Operators

### Install Postgres Operator

Install [PGO](https://access.crunchydata.com/documentation/postgres-operator/latest/installation/helm) (Crunchy Postgres Operator) from the official OCI registry:
```bash
helm install pgo oci://registry.developers.crunchydata.com/crunchydata/pgo \
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

Wait for the operator:
```bash
kubectl get pods --watch --namespace dask-operator
```

## Install Postgres Cluster

```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster \
    --set global.provisioner="csi.vsphere.vmware.com" \
    --namespace graphistry --create-namespace
```

Wait for postgres pods:
```bash
kubectl get pods --watch -n graphistry
```

**Note**: The `postgres-instance` pod will stay in `Pending` state. It requires the `retain-sc` storage class, which is created by `graphistry-resources` in the next step.

## Install Graphistry Resources

View available values:
```bash
helm show values ./charts/graphistry-helm-resources
```

Install the graphistry-resources chart using this command:
```bash
helm upgrade -i graphistry-resources ./charts/graphistry-helm-resources \
    --set global.provisioner="csi.vsphere.vmware.com" \
    --namespace graphistry --create-namespace
```

This chart creates the required storage classes using your provisioner (`csi.vsphere.vmware.com`).

### Storage Classes Created

| Storage Class | reclaimPolicy | Description |
|---------------|---------------|-------------|
| `retain-sc` | Retain | Data preserved when PVC deleted (manual cleanup required) |
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

The `postgres-cluster` chart creates a `PostgresCluster` CR. The PGO operator dynamically provisions PVCs using `retain-sc` for:
- Instance data volume (e.g., `postgres-instance1-xxxx-0`)
- Backup repository volume

Wait for resources (the `postgres-instance` pod should now start running):
```bash
kubectl get pods --watch -n graphistry
```

## Install Graphistry

Using the Tanzu-specific values file:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/tanzu/tanzu_example_values.yaml \
    --namespace graphistry --create-namespace
```

Wait for all pods to be running:
```bash
kubectl get pods --watch -n graphistry
```

## Access Graphistry

Get the ingress address:
```bash
kubectl get ingress -n graphistry
```

Open the ADDRESS in your browser and create an admin account.

## Update Graphistry Deployment

When updating, preserve existing volume bindings:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/tanzu/tanzu_example_values.yaml \
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

### Check Storage Class
```bash
kubectl get sc
kubectl describe sc csi.vsphere.vmware.com
```

### GPU Issues
```bash
# Check GPU operator status
kubectl get pods -n gpu-operator

# Check GPU availability on nodes
kubectl describe node <node-name> | grep -A 5 "Capacity:"
```

### Networking Issues

#### Verify Ingress Controller
```bash
# Check ingress controller is running
kubectl get pods -n ingress-nginx

# Check ingress controller service has external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Check ingress resource is created
kubectl get ingress -n graphistry
kubectl describe ingress caddy-ingress-graphistry -n graphistry
```

#### Verify Traffic Flow
```bash
# Test caddy health endpoint (from inside cluster)
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
    curl -v http://caddy-graphistry.graphistry.svc.cluster.local/caddy/health/

# Check caddy logs
kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep caddy) -f

# Check nginx logs
kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep nginx) -f
```

#### Common Networking Problems

1. **No external IP on LoadBalancer**: Tanzu may require MetalLB or NSX-T for LoadBalancer services
   ```bash
   # Check if service is pending
   kubectl get svc -n ingress-nginx
   # If EXTERNAL-IP shows <pending>, consider using NodePort instead:
   # --set controller.service.type=NodePort
   ```

2. **NSX-T blocking traffic**: Check with your vSphere admin for network policies

3. **Session affinity issues**: WebSocket connections may fail if affinity is not working
   ```bash
   # Verify ingress annotations
   kubectl get ingress -n graphistry -o yaml | grep -A5 annotations
   ```

4. **SSL/TLS issues**: If using `tls: true`, ensure cert-manager is installed
   ```bash
   kubectl get pods -n cert-manager
   kubectl get certificates -n graphistry
   ```

## Cleanup

```bash
# Uninstall Graphistry
helm uninstall g-chart -n graphistry

# Uninstall resources
helm uninstall graphistry-resources -n graphistry
helm uninstall postgres-cluster -n graphistry

# Uninstall operators
helm uninstall postgres-operator -n postgres-operator
helm uninstall dask-operator -n dask-operator

# Delete namespaces
kubectl delete namespace graphistry
kubectl delete namespace postgres-operator
kubectl delete namespace dask-operator
```

## References

- [Tanzu Kubernetes Grid Storage Documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/workload-clusters-storage.html)
- [vSphere CSI Driver](https://github.com/kubernetes-sigs/vsphere-csi-driver)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
- [Graphistry Admin Docs](https://graphistry-admin-docs.readthedocs.io/)
