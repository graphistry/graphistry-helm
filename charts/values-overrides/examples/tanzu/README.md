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

### GPU Access on vSphere

vSphere provides two ways to expose GPUs to Tanzu Kubernetes nodes:

| Mode | Description | Use Case |
|---|---|---|
| **GPU Passthrough** (DirectPath I/O) | Full GPU dedicated to a single VM. The VM sees the bare-metal GPU directly. | Best performance. Required for Graphistry's GPU-accelerated visualization. |
| **vGPU** (time-sliced) | GPU shared across multiple VMs via NVIDIA GRID/vGPU manager. Each VM gets a virtual GPU profile. | Multi-tenant environments where GPU sharing is needed. |

```
Physical Server (ESXi Host)
    |
    +-- NVIDIA GPU (e.g., T4, A100, A40)
        |
        +-- GPU Passthrough: Full GPU -> 1 VM -> Tanzu node
        |
        +-- vGPU: GPU sliced -> multiple VMs -> multiple Tanzu nodes
```

Tanzu nodes run **Photon OS** or **Ubuntu** (standard Linux), unlike GKE which uses Container-Optimized OS. This means the NVIDIA GPU Operator can install drivers directly on the node (`driver.enabled=true`).

Common GPU models for Tanzu/vSphere:
- **T4** - inference-optimized, widely deployed
- **A100/A30** - MIG support, high-performance training and inference
- **A40/L40S** - visualization and compute workloads
- **H100** - latest generation, MIG support

> **Note on GPU monitoring**: In vGPU mode, the DCGM profiling module may not have full access to the GPU hardware, which can affect GPU metrics collection. See [Fix DCGM GPU Metrics](#fix-dcgm-gpu-metrics-vgpu-environments) in the Telemetry section if your Grafana GPU dashboard shows no data.

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

## Pod Security Admission (PSA)

TKG clusters running Kubernetes v1.26+ [enforce the `restricted` Pod Security Standard](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/workload-security-psa.html) on non-system namespaces by default. The `restricted` profile requires containers to set `runAsNonRoot: true`, `seccompProfile`, and drop all Linux capabilities. Pods that don't meet these requirements are **rejected** by the admission controller.

**Graphistry requires the `privileged` label on its namespaces.** Most Graphistry containers (dask-cuda-worker, forge-etl-python, streamgl-gpu, nexus, nginx, caddy, redis, pivot, notebook, etc.) run as root by default and do not set a `securityContext`. This means they are blocked by the `restricted` profile regardless of whether telemetry is enabled. When telemetry is on, the DCGM exporter additionally requires the `SYS_ADMIN` Linux capability for GPU metrics collection.

The only Graphistry-managed pods that are already `restricted`-compatible are the PostgreSQL pods — PGO (Crunchy Postgres Operator) sets `runAsNonRoot: true`, `drop: ALL`, `readOnlyRootFilesystem`, and `seccompProfile: RuntimeDefault` on all its containers.

Label each namespace **before** deploying workloads into it:
```bash
# Required for GPU Operator (driver installer, device plugin)
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged

# Required for Graphistry services (run as root, no securityContext set)
kubectl label --overwrite ns graphistry pod-security.kubernetes.io/enforce=privileged
```

If you skip this step, pod creation will fail with a `Forbidden` error from the admission controller.

For more details, see the [Tanzu PSA documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/workload-security-psa.html) and the [NVIDIA GPU Operator on Tanzu guide](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vvs/1-0/private-ai-ready-infrastructure-for-vmware-cloud-foundation/implementation-of-ai-ready-infrastructure/deploy-and-configure-a-tanzu-kubernetes-cluster-for-vsphere-with-tanzu-for-ai-ready-infrastructure/deploy-and-configure-nvidia-kubernetes-operators-for-ai-ready-infrastructure.html).

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
kubectl label --overwrite ns gpu-operator pod-security.kubernetes.io/enforce=privileged

helm install --wait --generate-name \
    -n gpu-operator \
    nvidia/gpu-operator \
    --set driver.enabled=true \
    --set driver.version="<DRIVER_VERSION>" \
    --set cdi.enabled=true \
    --set cdi.default=true \
    --set 'toolkit.env[0].name=NVIDIA_RUNTIME_SET_AS_DEFAULT' \
    --set-string 'toolkit.env[0].value=true' \
    --timeout 60m
```

**Choose `<DRIVER_VERSION>` based on your CUDA version:**

Graphistry publishes Docker images for both CUDA 12.8 and CUDA 11.8. The `cuda.version` chart value selects which image variant to pull (e.g., `graphistry/nexus:v2.45.11-12.8` vs `graphistry/nexus:v2.45.11-11.8`). The GPU driver installed on the node must be compatible with the chosen CUDA version:

| CUDA Version | Minimum Driver | Recommended `driver.version` | Notes |
|---|---|---|---|
| 12.8 | >=570.26 | `570.195.03` | R570 branch or newer |
| 11.8 | >=520.61.05 | `535.288.01` | R535 branch or newer |

The chart default is `cuda.version: "12.8"`. If using CUDA 11.8, add `--set cuda.version="11.8"` to your Graphistry helm install command (the [Install Graphistry](#install-graphistry) step, not the GPU Operator). See the [NVIDIA CUDA Toolkit Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/) for the full driver compatibility matrix and the [GPU Operator Component Matrix](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#gpu-operator-component-matrix) for supported driver versions per operator release.

Notes:
1. `driver.enabled=true`: The GPU Operator installs the NVIDIA driver on Tanzu nodes (unlike GKE which uses a separate DaemonSet).
2. `NVIDIA_RUNTIME_SET_AS_DEFAULT=true`: Makes nvidia the default container runtime, so all pods get GPU access without explicit `nvidia.com/gpu` resource requests.

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
kubectl label --overwrite ns graphistry pod-security.kubernetes.io/enforce=privileged
```

### Create Docker Hub Secret
Your Docker Hub account must have access to Graphistry images. Contact [Graphistry Support](https://www.graphistry.com/support) to get access.
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

You must mirror all Graphistry images to your private registry before deployment, including the `groundnuty/k8s-wait-for:latest` image used by init containers across most Graphistry pods (nexus, nginx, pivot, forge-etl-python, streamgl-gpu, dask-scheduler, dask-cuda-worker, etc.). Without this image, pods will fail to start. Contact Graphistry support for the complete image list for your version.

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
helm upgrade --install ingress-nginx ./charts-aux-bundled/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer
```

Wait for the external IP:
```bash
kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch
```

**Note**: If your Tanzu cluster doesn't support LoadBalancer services (no [NSX Advanced Load Balancer (Avi)](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/mgmt-reqs-network-nsx-alb-overview.html) or MetalLB), use NodePort instead:
```bash
helm upgrade --install ingress-nginx ./charts-aux-bundled/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=NodePort
```
Then access Graphistry via `http://<node-ip>:<node-port>`.

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

Wait for the operator:
```bash
kubectl get pods --watch --namespace dask-operator
```

## Configure StorageClass

Graphistry requires a StorageClass with `reclaimPolicy: Retain` so data (postgres, uploads, notebooks, visualizations) is preserved across redeployments. All PVCs reference a single StorageClass name (default: `retain-sc`).

On Tanzu/vSphere, StorageClasses must be registered with a vSphere Storage Policy. Most Tanzu clusters already have pre-registered StorageClasses available.

### Option A: Create a New StorageClass

Use this reference template to create a StorageClass for Tanzu. Save as `retain-sc.yaml`:
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-sc
provisioner: csi.vsphere.vmware.com
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  storagepolicyname: "<your-vsphere-storage-policy>"
```

Replace `<your-vsphere-storage-policy>` with the name of your vSphere Storage Policy (e.g. `vSAN Default Storage Policy`).

Apply it:
```bash
kubectl apply -f retain-sc.yaml
```

### Option B: Use an Existing StorageClass

If you already have a StorageClass with `reclaimPolicy: Retain`, you can point all Graphistry PVCs to it by setting `global.storageClassNameOverride` in your values file:
```yaml
global:
  # Override the StorageClass name used by all PVCs (data-mount, local-media, gak-public,
  # gak-private, uploads-files, and postgres volumes). The StorageClass must be pre-created
  # by the cluster admin with reclaimPolicy: Retain to preserve data across redeployments.
  # When empty, defaults to "retain-sc" (single-node) or "retain-sc-cluster" (cluster mode).
  storageClassNameOverride: "your-existing-sc-name"
```

### StorageClass Requirements

| Property | Value | Description |
|----------|-------|-------------|
| `reclaimPolicy` | Retain | Data preserved when PVC deleted (manual cleanup required) |
| `volumeBindingMode` | WaitForFirstConsumer | PV created only when a pod needs it |
| `allowVolumeExpansion` | true | Allows resizing volumes without recreating them |

### PVCs and Services (graphistry-helm and postgres-cluster charts)

| PVC | Used By Services |
|-----|------------------|
| `data-mount` | nexus, nginx, forge-etl-python, streamgl-gpu, streamgl-viz, streamgl-sessions, dask-scheduler, dask-cuda-worker, redis, pivot, caddy, notebook |
| `local-media-mount` | nexus, nginx |
| `gak-public` | graph-app-kit-public, notebook |
| `gak-private` | graph-app-kit-private, notebook |
| `uploads-files` | nginx, forge-etl-python |

**Note**: The Postgres Cluster also requires the same StorageClass.

## Install Postgres Cluster

The `postgres-cluster` chart creates a `PostgresCluster` CR. The PGO operator dynamically provisions PVCs using the same StorageClass:
- Instance data volume (e.g., `postgres-instance1-xxxx-0`).
- Backup repository volume for pgBackRest.

```bash
helm show values ./charts/postgres-cluster
```

The chart defaults to StorageClass `retain-sc`, the same default used by the Graphistry chart.

In case you created the StorageClass as indicated in [Option A](#option-a-create-a-new-storageclass), install the cluster chart with the following command:

```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster \
    --namespace graphistry --create-namespace
```

In case you are using a custom StorageClass name ([Option B](#option-b-use-an-existing-storageclass)), pass it explicitly:

```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster \
    --set global.storageClassNameOverride=your-existing-sc-name \
    --namespace graphistry --create-namespace
```

Verify the pods are created. Since the StorageClass was configured in the previous step, the postgres pods should start running:
```bash
kubectl get pods --watch -n graphistry
```

**Note**: If pods stay in `Pending` state, verify the StorageClass is correctly configured (see [Configure StorageClass](#configure-storageclass)).

## Install Graphistry

Graphistry publishes Docker images for both CUDA 12.8 and CUDA 11.8. The `cuda.version` chart value selects which image variant to pull (e.g., `graphistry/nexus:v2.45.11-12.8`). You can set the CUDA and Graphistry versions by editing `./charts/values-overrides/examples/tanzu/tanzu_example_values.yaml`:
```yaml
cuda:
  version: "12.8"   # or "11.8" - must match the GPU driver installed above

global:  ## global settings for all charts
  tag: v2.45.11
```

Also verify that the values file references the correct Docker Hub pull secret ([Create Docker Hub Secret](#create-docker-hub-secret)) and StorageClass configuration ([Configure StorageClass](#configure-storageclass)):
```yaml
global:
  imagePullSecrets:
    - name: docker-secret-prod
  storageClassNameOverride: ""  # leave empty for default "retain-sc", or set to your custom SC name
```

Print more values:
```bash
helm show values ./charts/graphistry-helm
```

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

**Note**: If pods stay in `Pending` or `ImagePullBackOff` state, verify the StorageClass is correctly configured (see [Configure StorageClass](#configure-storageclass)) and that the Docker Hub secret is created with valid credentials (see [Create Docker Hub Secret](#create-docker-hub-secret)).

## Access Graphistry

Get the ingress address:
```bash
kubectl get ingress -n graphistry
```

All services share the same ingress IP (`ADDRESS` from the command above). When `ENABLE_OPEN_TELEMETRY: true` and `telemetryStack.OTEL_CLOUD_MODE: false` are set in your values file, the telemetry stack (Grafana, Prometheus, Jaeger) is deployed as part of the cluster:

| Service | Path |
|---|---|
| Graphistry | `http://<ADDRESS>/` |
| Grafana | `http://<ADDRESS>/grafana` |
| Jaeger | `http://<ADDRESS>/jaeger` |
| Prometheus | `http://<ADDRESS>/prometheus` |

Open Graphistry in the browser and create an admin account.

## Update Graphistry Deployment

When updating, preserve existing volume bindings so that data persists across redeployments. First, generate the `volumeName` block for your values file:

```bash
echo "volumeName:
  dataMount: $(kubectl get pvc data-mount -n graphistry -o jsonpath='{.spec.volumeName}')
  localMediaMount: $(kubectl get pvc local-media-mount -n graphistry -o jsonpath='{.spec.volumeName}')
  gakPublic: $(kubectl get pvc gak-public -n graphistry -o jsonpath='{.spec.volumeName}')
  gakPrivate: $(kubectl get pvc gak-private -n graphistry -o jsonpath='{.spec.volumeName}')"
```

Copy the output into your values file (e.g. `tanzu_example_values.yaml`), then run the normal upgrade command:

```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/tanzu/tanzu_example_values.yaml \
    --namespace graphistry --create-namespace
```

## Enabling Telemetry

Telemetry is enabled by default (`ENABLE_OPEN_TELEMETRY: true`). When `telemetryStack.OTEL_CLOUD_MODE: false` (the default in the example values), the following services are deployed as part of the cluster:
- **Grafana** - dashboards and metrics visualization (`/grafana`)
- **Prometheus** - metrics collection and alerting (`/prometheus`)
- **Jaeger** - distributed tracing (`/jaeger`)

Grafana includes pre-provisioned dashboards:
- **NVIDIA DCGM Exporter Dashboard** (`/grafana/d/Oxed_c6Wz/nvidia-dcgm-exporter-dashboard`) - GPU temperature, power usage, utilization, memory, SM clock
- **Node Exporter Full Dashboard** (`/grafana/d/rYdddlPWk/node-exporter-full`) - CPU, memory, disk, network metrics

### Fix DCGM GPU Metrics (vGPU environments)

Graphistry deploys its own DCGM exporter to collect GPU metrics. On Tanzu nodes using **vGPU** (time-sliced GPU sharing), the DCGM profiling module may fail:

```
ERROR msg="DCGM collector for entity type 'GPU' cannot be initialized;
  err: error watching fields: The third-party Profiling module returned an unrecoverable error"
```

This does not affect nodes using **GPU passthrough** (DirectPath I/O), where the VM has direct hardware access.

If you see this error, the GPU Operator already deploys a working DCGM exporter in the `gpu-operator` namespace. Point Graphistry's Prometheus to use it instead:

```bash
# Point Prometheus to the GPU Operator's DCGM exporter (cross-namespace)
kubectl get configmap prometheus-configmap -n graphistry -o yaml \
  | sed 's|dcgm-exporter:9400|nvidia-dcgm-exporter.gpu-operator.svc.cluster.local:9400|' \
  | kubectl apply -f -

# Restart Prometheus to pick up the new config
kubectl rollout restart daemonset/prometheus -n graphistry

# Remove the redundant Graphistry DCGM exporter
kubectl delete daemonset dcgm-exporter -n graphistry
kubectl delete service dcgm-exporter -n graphistry
```

Verify GPU metrics are flowing:
```bash
kubectl exec -n graphistry $(kubectl get pods -n graphistry -l io.kompose.service=prometheus -o name | head -1) \
  -- sh -c 'wget -qO- "http://localhost:9090/prometheus/api/v1/query?query=DCGM_FI_DEV_GPU_TEMP" 2>/dev/null'
```

> **Note**: This patch is applied at runtime. After a `helm upgrade`, you may need to re-apply it.

To send telemetry to an external provider (e.g., Grafana Cloud) instead, set `OTEL_CLOUD_MODE: true` and fill in the `openTelemetryCollector` credentials in your values file.

For more configuration options, see the [Graphistry Kubernetes Telemetry Documentation](https://graphistry-admin-docs.readthedocs.io/en/latest/telemetry/kubernetes.html).

## Troubleshooting

For comprehensive troubleshooting, debugging, and verification commands covering all deployment stages, see the [Troubleshooting Guide](../troubleshooting.md).

### Tanzu-Specific Notes

**Pod Security Admission (PSA)**: Tanzu enforces PSA by default. If pods fail to start with security policy violations, label the namespace:
```bash
kubectl label namespace graphistry pod-security.kubernetes.io/enforce=privileged --overwrite
```

**DCGM profiling error on vGPU environments**: The DCGM profiling module does not support vGPU. If `dcgm-exporter` is in CrashLoopBackOff, apply the configmap patch that disables profiling metrics (see the DCGM fix section earlier in this guide).

**NSX networking**: If the LoadBalancer EXTERNAL-IP stays `<pending>`, Tanzu requires [NSX Advanced Load Balancer (Avi)](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/mgmt-reqs-network-nsx-alb-overview.html) or MetalLB. Check with your vSphere admin for firewall rules and network policies.

**vSphere CSI StorageClass**: If PVCs are stuck Pending, verify the vSphere CSI driver is installed and the StorageClass provisioner matches your environment:
```bash
kubectl get sc
kubectl get pods -n vmware-system-csi
```

**SSL/TLS issues**: If using TLS, ensure cert-manager is installed and certificates are issued:
```bash
kubectl get pods -n cert-manager
kubectl get certificates -n graphistry
```

## Cleanup

```bash
# Uninstall Graphistry
helm uninstall g-chart -n graphistry

# Uninstall postgres-cluster
helm uninstall postgres-cluster -n graphistry

# Uninstall operators
helm uninstall pgo -n postgres-operator
helm uninstall dask-operator -n dask-operator

# Uninstall GPU Operator (--generate-name creates a dynamic release name)
helm list -n gpu-operator -q | xargs -I {} helm uninstall {} -n gpu-operator

# Uninstall ingress controller
helm uninstall ingress-nginx -n ingress-nginx

# Delete namespaces
kubectl delete namespace graphistry
kubectl delete namespace postgres-operator
kubectl delete namespace dask-operator
kubectl delete namespace gpu-operator
kubectl delete namespace ingress-nginx
```

## References

- [Tanzu Kubernetes Grid Storage Documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/standalone-components/tanzu-kubernetes-grid/2-5/tkg/workload-clusters-storage.html)
- [vSphere CSI Driver](https://github.com/kubernetes-sigs/vsphere-csi-driver)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
- [Graphistry Admin Docs](https://graphistry-admin-docs.readthedocs.io/)
