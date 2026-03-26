# Deploy a Graphistry K8s cluster using GKE
This guide provides step-by-step instructions for deploying Graphistry on Google Kubernetes Engine (GKE).  The steps are based on the official documentation of [Graphistry Helm Charts](https://github.com/graphistry/graphistry-helm) and the [NVIDIA GPU Operator with Google GKE](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/google-gke.html).

## Prerequisites

### gcloud
Install the `gcloud` CLI: donwload the Linux binaries from (e.g. `google-cloud-cli-477.0.0-linux-x86_64.tar.gz`):
https://cloud.google.com/sdk/docs/install

Verify the installation using:
```bash
gcloud --version
```
The output should be similar to:
```bash
# Google Cloud SDK 477.0.0
# beta 2024.05.17
# bq 2.1.4
# bundled-python3-unix 3.11.8
# core 2024.05.17
# gcloud-crc32c 1.0.0
# gke-gcloud-auth-plugin 0.5.8
# gsutil 5.29
# kubectl 1.27.14
```

### kubectl
Install `kubectl` compatible with `gcloud`:
```bash
gcloud components install kubectl
```

More details here:
https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl

Verify the installation using:
```bash
kubectl version
```

The output should be similar to:
```bash
# WARNING: This version information is deprecated and will be replaced with the output from kubectl version --short.  Use --output=yaml|json to get the full version.
# Client Version: version.Info{Major:"1", Minor:"27+", GitVersion:"v1.27.14-dispatcher", GitCommit:"643004a51a14c7a149377e6651fb926f17c06c5a", GitTreeState:"clean", BuildDate:"2024-05-15T21:18:29Z", GoVersion:"go1.21.9", Compiler:"gc", Platform:"linux/amd64"}
# Kustomize Version: v5.0.1
```

### Helm
Install Helm from:
https://github.com/helm/helm/releases

Download the `linux-amd64` version and add the binaries to the prefix path:
```bash
wget https://get.helm.sh/helm-v3.15.1-linux-amd64.tar.gz
```

Unzip the file:
```bash
tar xvf helm-v3.15.1-linux-amd64.tar.gz
```

Add the binary to the executable path:
```bash
export PATH=$PATH:$PWD/linux-amd64/
```

Verify the installation using:
```bash
helm version
```

The output should be similar to:
```bash
# version.BuildInfo{Version:"v3.15.1", GitCommit:"e211f2aa62992bd72586b395de50979e31231829", GitTreeState:"clean", GoVersion:"go1.22.3"}
```

## Create a K8S cluster
In this example the cluster will have a single node with only 1 GPU (`nvidia-tesla-t4`):
```bash
gcloud beta container clusters create demo-cluster \
      --zone us-central1-a \
      --release-channel "regular" \
      --machine-type "n1-highmem-8" \
      --accelerator "type=nvidia-tesla-t4,count=1,gpu-driver-version=disabled" \
      --image-type "UBUNTU_CONTAINERD" \
      --disk-type "pd-standard" \
      --disk-size "1000" \
      --no-enable-intra-node-visibility \
      --metadata disable-legacy-endpoints=true \
      --max-pods-per-node "110" \
      --num-nodes "1" \
      --logging=SYSTEM,WORKLOAD \
      --monitoring=SYSTEM \
      --enable-ip-alias \
      --default-max-pods-per-node "110" \
      --no-enable-master-authorized-networks \
      --tags=nvidia-ingress-all
```

- `--accelerator type=nvidia-tesla-t4,count=1`: Attaches 1 Tesla T4 GPU to each node.
- `gpu-driver-version=disabled`: Disables GKE's automatic GPU driver installation so we can install the driver manually via DaemonSet (see next step). GKE's `default` installs R535 and `latest` installs R580. For Graphistry's CUDA 12 build (driver 535+) the R570 DaemonSet is recommended; for the CUDA 13 build (driver 590+) you need an R590+ driver.
- `--image-type "UBUNTU_CONTAINERD"`: Ubuntu is required because Google provides a pre-built [R570 driver DaemonSet](https://github.com/GoogleCloudPlatform/container-engine-accelerators/blob/master/nvidia-driver-installer/ubuntu/daemonset-preloaded-R570.yaml) for Ubuntu but not for COS.
- `--machine-type "n1-highmem-8"`: 8 vCPUs / 52 GB RAM. T4 GPUs [only attach to N1 machines](https://docs.cloud.google.com/compute/docs/gpus) (max 24 vCPUs with 1 T4). The `n1-highmem-4` (4 vCPUs) is too small — the PostgreSQL Operator (PGO) reserves ~1 CPU with Guaranteed QoS, and backup CronJobs need additional CPU to schedule. With 4 vCPUs the node runs at ~96% CPU, causing backup pods to stay Pending and block all downstream services.

## Get cluster credentials
The next command should fill the credentials in `~/.kube/config`:
```bash
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
    gcloud container clusters get-credentials demo-cluster --zone us-central1-a
```

Verify the credentials and the cluster labels:
```bash
kubectl get nodes --show-labels
```

Also, let's print the current configuration:
```bash
cat ~/.kube/config
```

## Test the K8S cluster
```bash
kubectl get nodes -o wide
```

Check the resources:
```bash
kubectl get all
```

## Install NVIDIA GPU Driver

The recommended driver for Graphistry's CUDA 12 flavor is R575+ and for CUDA 13 is R590+ (see driver compatibility table above). However, Google's pre-built [driver DaemonSets](https://github.com/GoogleCloudPlatform/container-engine-accelerators/tree/master/nvidia-driver-installer/ubuntu) currently only go up to R570. Check that repository for newer versions before proceeding. If R575+ or R590+ are not yet available, R570 may work with the CUDA 12 flavor via NVIDIA's [forward compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/) layer.

### Install R570 Driver DaemonSet (CUDA 12)

With `gpu-driver-version=disabled`, the GPU driver must be installed manually. Google provides a pre-built [R570 DaemonSet](https://github.com/GoogleCloudPlatform/container-engine-accelerators/blob/master/nvidia-driver-installer/ubuntu/daemonset-preloaded-R570.yaml) for Ubuntu, but it hardcodes driver version `570.124.06` which may not have a pre-built package for your node's kernel version.

First, check which R570 driver version is available for your kernel:
```bash
KERNEL_VERSION=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kernelVersion}')
```

Then print the kernel version:
```bash
echo "Kernel: $KERNEL_VERSION"
```

Then check if the driver packages will match the kernel:
```bash
curl -s "https://www.googleapis.com/storage/v1/b/ubuntu_nvidia_packages/o?prefix=nvidia-driver-gke_noble-${KERNEL_VERSION}-570" \
    | python3 -c "import sys,json; [print(i['name']) for i in json.load(sys.stdin).get('items',[])]" \
    | grep amd64
```

Then apply the DaemonSet, replacing the driver version if needed (e.g. `570.133.20` for newer kernels):
```bash
curl -s https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/master/nvidia-driver-installer/ubuntu/daemonset-preloaded-R570.yaml \
    | sed 's/570.124.06/570.133.20/g' \
    | kubectl apply -f -
```

Wait for the driver installer to complete:
```bash
kubectl get pods -n kube-system -l k8s-app=nvidia-driver-installer --watch
```

Verify the driver is installed:
```bash
kubectl logs -n kube-system -l k8s-app=nvidia-driver-installer -c nvidia-driver-installer --tail=20
```

**Why R570?** R570 is the newest driver available in Google's pre-built [driver DaemonSets](https://github.com/GoogleCloudPlatform/container-engine-accelerators/tree/master/nvidia-driver-installer/ubuntu). GKE's built-in driver options (`default`=R535, `latest`=R580) do not match our recommended R575+ for CUDA 12 or R590+ for CUDA 13. R570 works with Graphistry's CUDA 12 flavor via NVIDIA's forward compatibility layer. Check the repository for newer DaemonSets (R575+, R590+) as they become available.

## Setup the NVIDIA GPU Operator
Create the namespace:
```bash
kubectl create ns gpu-operator
```

Create the resource quota:
```bash
kubectl apply -n gpu-operator -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: gpu-operator-quota
spec:
  hard:
    pods: 100
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values:
        - system-node-critical
        - system-cluster-critical
EOF
```

Verify using:
```bash
kubectl get -n gpu-operator resourcequota
```

Remove the old `nvidia` repository from Helm:
```bash
helm repo remove nvidia
```

Add the current `nvidia` repository to Helm:
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia \
    && helm repo update
```

Check if Node Feature Discovery (NFD) is already enabled on the cluster. The GPU Operator includes NFD by default, but if the cluster already has it, you must disable the operator's copy to avoid conflicts:
```bash
kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'
```

If the output is `true`, add `--set nfd.enabled=false` to the next `helm install` command. If `false` (typical for GKE), no change is needed.

Install the GPU Operator (the R570 DaemonSet manages the driver, so `driver.enabled=false`):
```bash
helm install --wait --generate-name \
    -n gpu-operator \
    nvidia/gpu-operator \
    --version=v25.10.1 \
    --set driver.enabled=false \
    --set hostPaths.driverInstallDir=/home/kubernetes/bin/nvidia \
    --set toolkit.installDir=/home/kubernetes/bin/nvidia \
    --set cdi.enabled=true \
    --set cdi.default=true \
    --set 'toolkit.env[0].name=RUNTIME_CONFIG_SOURCE' \
    --set 'toolkit.env[0].value=file' \
    --set 'toolkit.env[1].name=NVIDIA_RUNTIME_SET_AS_DEFAULT' \
    --set-string 'toolkit.env[1].value=true' \
    --timeout 60m
```

Notes:
1. `driver.enabled=false`: The R570 DaemonSet manages the GPU driver. The [NVIDIA GPU Operator Component Matrix](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#gpu-operator-component-matrix) lists supported driver versions.
2. `RUNTIME_CONFIG_SOURCE=file` is required for GKE's containerd 2.0+ (config v3 format).
3. `NVIDIA_RUNTIME_SET_AS_DEFAULT=true` makes nvidia the default container runtime, so all pods get GPU access without explicit `nvidia.com/gpu` resource requests (equivalent to k3s `--default-runtime nvidia`).

Check the cluster labels again, it should have GPU accelerator support for the K8s node selector:
```bash
kubectl get nodes --show-labels | sed  's/\,/\n/g' | grep "nvidia.com/gpu.present"
```

The output should be similar to:
```bash
nvidia.com/gpu.present=true
```

Wait until all pods are running or completed using the next command:
```bash
kubectl get pods -n gpu-operator --watch
```

Test we have applied corrrectly the operator using:
```bash
kubectl get nodes -ojson | jq .items[].status.capacity | grep nvidia.com/gpu
```

The output should be similar to:
```bash
# output example: "nvidia.com/gpu": "1",
```

**Note**: We don't need to install the NVIDIA Device Plugin given that we are using the NVIDIA GPU Operator.

## Inspect the NVIDIA GPU Operator (optional)
Print all resources of the `gpu-operator` namespace:
```bash
kubectl get all -n gpu-operator
```

Get all NVIDIA resources:
```bash
kubectl get po -n gpu-operator -A | grep nvidia
```

Describe the operator:
```bash
kubectl describe deployment gpu-operator -n gpu-operator
```

Describe the replica set:
```bash
kubectl describe rs gpu-operator -n gpu-operator
```

## Create the graphistry namespace
```bash
kubectl create namespace graphistry
```

## Create the secrets for Docker Hub and GAK
Your Docker Hub account must have access to Graphistry images. Contact [Graphistry Support](https://www.graphistry.com/support) to get access.
```bash
kubectl create secret docker-registry docker-secret-prod \
    --namespace graphistry \
    --docker-server=docker.io \
    --docker-username=user123 \
    --docker-password=thepassword
```

This step is optional, for more information visit [graph-app-kit](https://github.com/graphistry/graph-app-kit).
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gak-secret
  namespace: graphistry
type: Opaque
stringData:
  username: gke_graphistry_user1
  password: gke_graphistry_password1
EOF
```

Verify the secrets using:
```bash
kubectl get secret -n graphistry
```

## Get Graphistry Helm charts
```bash
git clone https://github.com/graphistry/graphistry-helm
```

Run the bundler:
```bash
cd graphistry-helm && bash chart-bundler/bundler.sh
```

## Install NGINX Ingress Controller
```bash
helm upgrade --install ingress-nginx ./charts-aux-bundled/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer
```

Verify the `EXTERNAL-IP` (this will be used to access to the cluster from the browser):
```bash
kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch
```

## Install Dask Operator and CRDs
```bash
cd charts-aux-bundled/dask-kubernetes-operator/ && helm dep build && cd ../..
```

Install the Dask operator chart using this command:
```bash
helm upgrade -i dask-operator ./charts-aux-bundled/dask-kubernetes-operator --namespace dask-operator --create-namespace
```

Wait until the operator is ready and running:
```bash
kubectl get pods --watch --namespace dask-operator
```

## Install Postgres Operator

Install [PGO](https://access.crunchydata.com/documentation/postgres-operator/latest/installation/helm) (Crunchy Postgres Operator):
```bash
helm install pgo ./charts-aux-bundled/pgo \
    --namespace postgres-operator --create-namespace
```

Wait for the operator:
```bash
kubectl get pods --watch --namespace postgres-operator
```

## Configure StorageClass

Graphistry requires a StorageClass with `reclaimPolicy: Retain` so data (postgres, uploads, notebooks, visualizations) is preserved across redeployments. All PVCs reference a single StorageClass name (default: `retain-sc`).

### Option A: Create a New StorageClass

Create a StorageClass for GKE:
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-sc
provisioner: pd.csi.storage.gke.io
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: pd-balanced
EOF
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
Graphistry v2.50.0+ uses RAPIDS 26.02 and publishes Docker images in two flavors: CUDA 12 and CUDA 13. The `cuda.version` chart value accepts `"12"` or `"13"` and selects which image variant to pull (e.g., `graphistry/nexus:v2.50.0-12`). Internally, Graphistry builds on top of RAPIDS base images (`rapidsai/base:26.02-cuda12-py3.10` and `rapidsai/base:26.02-cuda13-py3.10`), which ship specific CUDA toolkit versions that determine the minimum driver requirement:

| Graphistry Build | RAPIDS | CUDA Toolkit in Image | Recommended Min Driver | Verified On |
|---|---|---|---|---|
| `cuda.version: "12"` | 26.02 | 12.9.1 | R575+ (575.51.03+) | driver 575.57.08 (CUDA 12.9), driver 580.126.20 (CUDA 13.0) |
| `cuda.version: "13"` | 26.02 | 13.1.0 | R590+ (590.44.01+) | driver 590.48.01 (CUDA 13.1) |

We recommend the driver versions in the table above. Older drivers may work via NVIDIA's [forward compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/) layer but are not verified by Graphistry. The CUDA 13 flavor requires R590+ because the RAPIDS 26.02 base image (`rapidsai/base:26.02-cuda13-py3.10`) bakes CUDA 13.1 runtime (`CUDA_VERSION=13.1.0`), not 13.0. See the [RAPIDS Platform Support](https://docs.rapids.ai/platform-support/) matrix and [NVIDIA CUDA Toolkit Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/) for the full driver compatibility matrix.

You can set the CUDA and Graphistry versions by editing `./charts/values-overrides/examples/gke/gke_example_values.yaml`:
```yaml
cuda:
  version: "12"   # or "13" - must match the GPU driver installed above

global:  ## global settings for all charts
  tag: v2.50.0
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

Check we have all the secrets:
```bash
kubectl get secret -n graphistry | grep docker-secret-prod
```

Install Graphistry using the next command:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/gke/gke_example_values.yaml \
    --namespace graphistry --create-namespace
```

Wait until all the pods are running and completed:
```bash
kubectl get pods --watch -n graphistry
```

**Note**: If pods stay in `Pending` or `ImagePullBackOff` state, verify the StorageClass is correctly configured (see [Configure StorageClass](#configure-storageclass)) and that the Docker Hub secret is created with valid credentials (see [Create the secrets for Docker Hub and GAK](#create-the-secrets-for-docker-hub-and-gak)).

It's possible to get the public cluster address using this command (this IP is the `ADDRESS` of the `ingress-controller`):
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

Grafana includes pre-provisioned dashboards:
- **NVIDIA DCGM Exporter Dashboard** (`/grafana/d/Oxed_c6Wz/nvidia-dcgm-exporter-dashboard`) - GPU temperature, power usage, utilization, memory, SM clock
- **Node Exporter Full Dashboard** (`/grafana/d/rYdddlPWk/node-exporter-full`) - CPU, memory, disk, network metrics

Once you open Graphistry in the browser, create an account for the admin user with the email and password.

### Fix DCGM GPU Metrics on GKE (when telemetry is enabled)

When `ENABLE_OPEN_TELEMETRY: true` and `telemetryStack.OTEL_CLOUD_MODE: false`, Graphistry deploys its own DCGM exporter. On GKE, this exporter fails to collect GPU metrics because the DCGM profiling module is incompatible with GKE's Container-Optimized OS nodes:

```
ERROR msg="DCGM collector for entity type 'GPU' cannot be initialized;
  err: error watching fields: The third-party Profiling module returned an unrecoverable error"
```

The GPU Operator already deploys a working DCGM exporter in the `gpu-operator` namespace. To fix the Grafana GPU dashboards, point Graphistry's Prometheus to scrape it instead and remove the redundant Graphistry DCGM exporter:

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

> **Note**: This patch is applied at runtime. After a `helm upgrade`, you may need to re-apply it if the configmap is overwritten.

## Update Graphistry deployment

When updating, preserve existing volume bindings so that data persists across redeployments. First, generate the `volumeName` block for your values file:

```bash
echo "volumeName:
  dataMount: $(kubectl get pvc data-mount -n graphistry -o jsonpath='{.spec.volumeName}')
  localMediaMount: $(kubectl get pvc local-media-mount -n graphistry -o jsonpath='{.spec.volumeName}')
  gakPublic: $(kubectl get pvc gak-public -n graphistry -o jsonpath='{.spec.volumeName}')
  gakPrivate: $(kubectl get pvc gak-private -n graphistry -o jsonpath='{.spec.volumeName}')"
```

Copy the output into your values file (e.g. `gke_example_values.yaml`), then run the normal upgrade command:

```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/gke/gke_example_values.yaml \
    --namespace graphistry --create-namespace
```

## Enabling Telemetry
See [Graphistry Telemetry for Kubernetes](https://github.com/graphistry/graphistry-cli/blob/master/docs/telemetry/kubernetes.md).

## Delete k8s cluster
Delete the Graphistry chart:
```bash
helm uninstall g-chart -n graphistry
```

Delete the StorageClass:
```bash
kubectl delete sc retain-sc --ignore-not-found
```

Delete the `postgres-cluster` chart:
```bash
helm uninstall postgres-cluster -n graphistry
```

Delete the `postgres-operator` chart:
```bash
helm uninstall pgo -n postgres-operator
```

Delete the `dask-operator` chart:
```bash
helm uninstall dask-operator -n dask-operator
```

Delete the GPU Operator (`--generate-name` creates a dynamic release name):
```bash
helm list -n gpu-operator -q | xargs -I {} helm uninstall {} -n gpu-operator
```

Delete the docker registry secrets:
```bash
kubectl delete secret docker-secret-prod -n graphistry
```

Verify that no pods are running for the `graphistry` namespace:
```bash
kubectl get pods --namespace graphistry
```

Delete namespaces:
```bash
kubectl delete namespace graphistry
kubectl delete namespace postgres-operator
kubectl delete namespace dask-operator
kubectl delete namespace gpu-operator
```

Also, it's possible to delete the K8s cluster:
```bash
gcloud container clusters delete demo-cluster --zone us-central1-a
```

## Troubleshooting

For comprehensive troubleshooting, debugging, and verification commands covering all deployment stages, see the [Troubleshooting Guide](../troubleshooting.md).

### GKE-Specific Notes

**DCGM profiling error on COS nodes**: The DCGM profiling module is incompatible with GKE Container-Optimized OS (COS). If `dcgm-exporter` is in CrashLoopBackOff, apply the configmap patch that disables profiling metrics (see the DCGM fix section earlier in this guide).

**GKE GPU driver version**: GKE auto-installs GPU drivers by default. If you need a specific driver version (e.g., R575+ for CUDA 12 or R590+ for CUDA 13), use `--gpu-driver-version=disabled` at cluster creation and install the driver manually via DaemonSet (see the GPU Driver Install section earlier in this guide).

**n1-highmem-4 resource pressure**: PGO backup pods may stay Pending on `n1-highmem-4` instances due to insufficient CPU. Use `n1-highmem-8` or larger.
