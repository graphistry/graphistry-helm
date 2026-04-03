# Deploy Graphistry on k3s

This guide provides step-by-step instructions for deploying Graphistry on k3s, a lightweight Kubernetes distribution.

## Prerequisites

### Requirements
- A machine with one or more NVIDIA GPUs
- NVIDIA drivers installed on the host, or use the GPU Operator to install them (see [Option 1](#option-1-nvidia-gpu-operator-recommended))
- Ubuntu 22.04+ or similar Linux distribution

### Install k3s

The install command below configures k3s with the NVIDIA container runtime and sets up kubeconfig permissions so non-root users in the specified group can run `kubectl` and `helm` without `sudo`:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --default-runtime nvidia \
    --write-kubeconfig-mode 640 \
    --write-kubeconfig-group <your-group> \
    --node-name <your-node-name> \
    --data-dir <your-data-dir>" sh -
```

Replace `<your-group>` with the OS group whose members should have kubectl access (e.g., your user's group, `graphistry`, `docker`, `sudo`), `<your-node-name>` with a name for this node, and `<your-data-dir>` with the path where k3s stores its data (images, PVCs, state).

| Flag | Purpose |
|------|---------|
| `--default-runtime nvidia` | Sets NVIDIA as the default container runtime (required for GPU pods) |
| `--write-kubeconfig-mode 640` | Makes kubeconfig readable by group members (default is 600, root-only) |
| `--write-kubeconfig-group <group>` | Sets the group owner of `/etc/rancher/k3s/k3s.yaml` |
| `--node-name <name>` | Sets a custom node name instead of the hostname |
| `--data-dir <path>` | Optional. Where k3s stores images, PVCs, and state. Defaults to `/var/lib/rancher/k3s` (root disk). Graphistry images are large (~14GB each), so use a separate disk if root has limited space (e.g., `--data-dir /mnt/data/var/lib/rancher/k3s`). Can also be set later via `/etc/rancher/k3s/config.yaml` with `data-dir: /mnt/data/var/lib/rancher/k3s` |

Set up KUBECONFIG so `kubectl` and `helm` work as a non-root user. The recommended approach is per-user via your shell's rc file since it is permanent and under the control of the user running the deployment:

```bash
# Recommended: per-user, permanent for all new terminal windows
# Use ~/.bashrc for bash, ~/.zshrc for zsh, or ~/.config/fish/config.fish for fish
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc
```

Other alternatives:

| Method | Command | Scope |
|--------|---------|-------|
| Current session only | `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` | This terminal only, lost on close |
| Per user (recommended) | Add `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` to `~/.bashrc`, `~/.zshrc`, etc. | All new terminal windows for this user |
| All users, all sessions | Add `KUBECONFIG=/etc/rancher/k3s/k3s.yaml` to `/etc/environment` | Every new session (terminal, SSH, graphical) |
| All users, login shells only | Add `export KUBECONFIG=/etc/rancher/k3s/k3s.yaml` to `/etc/profile.d/k3s-env.sh` | SSH and `bash --login` only, not desktop terminals |

Install Helm if not already present:

```bash
command -v helm &>/dev/null || curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Verify k3s Installation
```bash
kubectl get nodes -o wide
```

## Install NVIDIA GPU Support

### Option 1: NVIDIA GPU Operator (Recommended)
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia --force-update

helm repo update

# Operator installs the NVIDIA driver on the node
helm install --wait --generate-name \
    -n gpu-operator --create-namespace nvidia/gpu-operator \
    --set driver.version="<DRIVER_VERSION>" \
    --timeout 60m
```

If the NVIDIA driver is already installed on the host (e.g., via `apt` or `.run` installer):
```bash
# Use the host driver - operator manages device plugin and toolkit only
helm install --wait --generate-name \
    -n gpu-operator --create-namespace nvidia/gpu-operator \
    --set driver.enabled=false \
    --timeout 60m
```

Graphistry v2.50.1+ uses RAPIDS 26.02 and publishes Docker images in two flavors: CUDA 12 and CUDA 13. The `cuda.version` chart value accepts `"12"` or `"13"` and selects which image variant to pull (e.g., `graphistry/nexus:v2.50.1-12`). Internally, Graphistry builds on top of RAPIDS base images (`rapidsai/base:26.02-cuda12-py3.10` and `rapidsai/base:26.02-cuda13-py3.10`), which ship specific CUDA toolkit versions that determine the minimum driver requirement:

| Graphistry Build | RAPIDS | CUDA Toolkit in Image | Recommended Min Driver | Verified On |
|---|---|---|---|---|
| `cuda.version: "12"` | 26.02 | 12.9.1 | R575+ (575.51.03+) | k3s: R575 (575.57.08), R580 (580.126.20), R590 (590.44.01), R595 (595.58.03). GKE: R570 (570.133.20, T4, forward compat) |
| `cuda.version: "13"` | 26.02 | 13.1.0 | R590+ (590.44.01+) | k3s: R590 (590.44.01), R595 (595.58.03). Docker compose: R590 (590.48.01) |

We recommend the driver versions in the table above. Older drivers may work via NVIDIA's [forward compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/) layer but are not verified by Graphistry. The chart default is `cuda.version: "12"`. The CUDA 13 flavor requires R590+ because the RAPIDS 26.02 base image (`rapidsai/base:26.02-cuda13-py3.10`) bakes CUDA 13.1 runtime (`CUDA_VERSION=13.1.0`), not 13.0. See the [RAPIDS Platform Support](https://docs.rapids.ai/platform-support/) matrix and [NVIDIA CUDA Toolkit Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/) for the full driver compatibility matrix.

Wait for the operator pods to be ready:
```bash
kubectl get pods -n gpu-operator --watch
```

### Option 2: NVIDIA Device Plugin
Lightweight alternative for clusters with NVIDIA drivers already installed on the host (e.g., DGX systems, GPU workstations):
```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.4/deployments/static/nvidia-device-plugin.yml
```

**Important:** The device plugin only registers `nvidia.com/gpu` as a resource in the node's Capacity/Allocatable. It does NOT add the `nvidia.com/gpu.present=true` node label (that label is set by GPU Feature Discovery, which is part of the GPU Operator). Graphistry's default `nodeSelector` requires this label, so you must add it manually on each GPU node:

```bash
kubectl label node <node-name> nvidia.com/gpu.present=true
```

### Verify GPU Access

Verify the GPU is detected by the operator:
```bash
kubectl get nodes --show-labels | grep "nvidia.com/gpu.present"

kubectl get nodes -ojson | jq '.items[].status.capacity' | grep nvidia.com/gpu
```

Or print the full GPU specs:
```bash
kubectl get nodes -ojson | jq '.items[].status.capacity | select(.["nvidia.com/gpu"] != null)'
```

Example output (in case of 2 GPUs):
```json
{
  "cpu": "32",
  "ephemeral-storage": "959786032Ki",
  "hugepages-1Gi": "0",
  "hugepages-2Mi": "0",
  "memory": "131658668Ki",
  "nvidia.com/gpu": "2",
  "pods": "110"
}
```

Test that a GPU container can actually run (creates a temporary pod, waits for the image to pull, and cleans up after itself):

```bash
(GPU_TEST_POD=graphistry-gpu-test-$$; \
  kubectl delete pod $GPU_TEST_POD --ignore-not-found && \
  kubectl run $GPU_TEST_POD --restart=Never --image=nvidia/cuda:12.8.0-base-ubuntu24.04 -- nvidia-smi && \
  kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/$GPU_TEST_POD --timeout=300s && \
  kubectl logs $GPU_TEST_POD; \
  kubectl delete pod $GPU_TEST_POD --ignore-not-found)
```

Note: the first run may take a few minutes while the CUDA image is pulled. The `kubectl wait` handles this automatically with a 5 minute timeout.

Expected output: nvidia-smi table showing your GPU model, driver version, and CUDA version. The driver must be in the compatible range for your chosen Graphistry CUDA build: R575+ for CUDA 12 (R570+ via forward compat), R590+ for CUDA 13. See the [troubleshooting guide](../troubleshooting.md#2-gpu-support) for the full driver compatibility table.

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

Prepare the operator:
```bash
cd charts-aux-bundled/dask-kubernetes-operator/ && helm dep build && cd ../..
```

Install the operator:
```bash
helm upgrade -i dask-operator ./charts-aux-bundled/dask-kubernetes-operator \
    --namespace dask-operator --create-namespace
```

Wait until the operator is ready and running:
```bash
kubectl get pods --watch --namespace dask-operator
```

## Create Graphistry Namespace and Secrets

### Create Namespace
```bash
kubectl create namespace graphistry
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

## Configure StorageClass

Graphistry requires a StorageClass with `reclaimPolicy: Retain` so data (postgres, uploads, notebooks, visualizations) is preserved across redeployments. All PVCs reference a single StorageClass name (default: `retain-sc`).

### Option A: Create a New StorageClass

Create a StorageClass for k3s:
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-sc
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
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

**Notes**:
- The Postgres Cluster also requires the same StorageClass.
- The notebook service mounts `data-mount` at `/home/graphistry/notebooks/` (subPath: `notebooks`). Only files saved under this directory persist across redeployments. The default demo notebooks at `/home/graphistry/demos/` are baked into the Docker image and reset when the image tag changes. To preserve your work, save or copy notebooks to `/home/graphistry/notebooks/`.

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

## Deployment Tiers

Graphistry supports four deployment tiers, each building on the previous. Set `global.tier` in your values file to control which services are deployed:

```yaml
global:
  tier: "full"   # platform | analytics | viz | full
```

Each tier includes all capabilities of the previous tiers:

| Tier | Description | GPU Required |
|------|-------------|:------------:|
| `platform` | `postgres` + `nexus`. Auth provider, foundation for Louie or other integrations. Minimum tier, services in the same namespace connect internally via `http://nexus:8000`. For external access use port-forward (`kubectl port-forward -n graphistry svc/nexus 8000:8000`) or create an Ingress. | No |
| `analytics` | `platform` + `caddy`, `nginx`, `redis`, `dask-scheduler`, `dask-cuda-worker`, `forge-etl-python`. Public API access, GPU compute, ETL processing and GFQL graph queries. | Yes |
| `viz` | `analytics` + `streamgl-sessions`, `streamgl-gpu`, `streamgl-viz`. Interactive graph visualization with WebGL rendering and real-time GPU layout. | Yes |
| `full` | `viz` + `pivot`, `notebook`, `graph-app-kit` (public/private). Investigation tools (Pivot), Jupyter notebooks and Streamlit dashboards. **Default tier**. | Yes |

### Services per tier

| Service | platform | analytics | viz | full |
|---------|:--------:|:---------:|:---:|:----:|
| `postgres` (postgres-cluster chart) | X | X | X | X |
| `nexus` | X | X | X | X |
| `caddy` | | X | X | X |
| `nginx` | | X | X | X |
| `redis` | | X | X | X |
| `dask-scheduler` | | X | X | X |
| `dask-cuda-worker` | | X | X | X |
| `forge-etl-python` | | X | X | X |
| `streamgl-sessions` | | | X | X |
| `streamgl-gpu` | | | X | X |
| `streamgl-viz` | | | X | X |
| `pivot` | | | | X |
| `notebook` | | | | X |
| `graph-app-kit-public` | | | | X |
| `graph-app-kit-private` | | | | X |

### PVCs per tier

| PVC | platform | analytics | viz | full |
|-----|:--------:|:---------:|:---:|:----:|
| `data-mount` (64Gi) | X | X | X | X |
| `local-media-mount` (4Gi) | X | X | X | X |
| `uploads-files` (40Gi) | | X | X | X |
| `gak-public` (4Gi) | | | | X |
| `gak-private` (4Gi) | | | | X |

### Tiers and telemetry

Telemetry is orthogonal to the deployment tier. It is controlled independently via `global.ENABLE_OPEN_TELEMETRY` (default: `true`). When enabled, the telemetry stack (otel-collector, Grafana, Prometheus, Jaeger, DCGM exporter, node exporter) deploys alongside whichever tier is selected. Services that are deployed export traces and metrics automatically; services not included in the tier simply don't emit data.

## Install Graphistry

You can set the CUDA and Graphistry versions by editing `./charts/values-overrides/examples/k3s/k3s_example_values.yaml` (see the driver compatibility table in the [GPU Support](#option-1-nvidia-gpu-operator-recommended) section above for accepted `cuda.version` values and driver requirements):
```yaml
cuda:
  version: "13"   # or "12" - must match the GPU driver installed above

global:  ## global settings for all charts
  tag: v2.50.1
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

**Note**: If pods stay in `Pending` or `ImagePullBackOff` state, verify the StorageClass is correctly configured (see [Configure StorageClass](#configure-storageclass)) and that the Docker Hub secret is created with valid credentials (see [Create Docker Hub Secret](#create-docker-hub-secret)).

## Access Graphistry

Get the service address:
```bash
kubectl get services -n graphistry | grep caddy
```

For k3s with Traefik ingress:
```bash
kubectl get ingress -n graphistry
```

All services share the same ingress IP (`ADDRESS` from the command above). When `ENABLE_OPEN_TELEMETRY: true` and `telemetryStack.OTEL_CLOUD_MODE: false` are set in your values file, the telemetry stack (Grafana, Prometheus, Jaeger) is deployed alongside Graphistry:

| Service | Path |
|---|---|
| Graphistry | `http://<ADDRESS>/` |
| Grafana | `http://<ADDRESS>/grafana` |
| Jaeger | `http://<ADDRESS>/jaeger` |
| Prometheus | `http://<ADDRESS>/prometheus` |

Once you open Graphistry in the browser, create an account for the admin user with the email and password.

## Update Graphistry Deployment

When updating, preserve existing volume bindings so that data persists across redeployments. First, generate the `volumeName` block for your values file:

```bash
echo "volumeName:
  dataMount: $(kubectl get pvc data-mount -n graphistry -o jsonpath='{.spec.volumeName}')
  localMediaMount: $(kubectl get pvc local-media-mount -n graphistry -o jsonpath='{.spec.volumeName}')
  uploadsFiles: $(kubectl get pvc uploads-files -n graphistry -o jsonpath='{.spec.volumeName}')
  gakPublic: $(kubectl get pvc gak-public -n graphistry -o jsonpath='{.spec.volumeName}')
  gakPrivate: $(kubectl get pvc gak-private -n graphistry -o jsonpath='{.spec.volumeName}')"
```

Copy the output into your values file (e.g. `k3s_example_values.yaml`), then run the normal upgrade command:

```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/k3s/k3s_example_values.yaml \
    --namespace graphistry --create-namespace
```

If pods stay in `Pending` state after a reinstall, the PVs may have a stale `claimRef`. This commonly happens when you `helm uninstall` the Graphistry chart and then reinstall it: the StorageClass uses `reclaimPolicy: Retain`, so the PVs survive the uninstall but remain bound to the old (now deleted) PVCs. The new PVCs cannot bind to those PVs until the stale `claimRef` is cleared.

After `helm uninstall`, PVs take up to 60 seconds to transition from `Bound` to `Released`. Watch for the transition before clearing the claimRef:

```bash
# Watch until PVs show Released (Ctrl+C once you see them)
kubectl get pv --watch | grep Released

# Then clear the stale claimRef
kubectl get pv -o json | \
    jq -r '.items[] | select(.status.phase=="Released") | select(.spec.claimRef.namespace=="graphistry") | .metadata.name' | \
    xargs -I {} kubectl patch pv {} -p '{"spec":{"claimRef": null}}'
```

Then re-run the helm upgrade. The PVCs will bind to the existing PVs via the `volumeName` field, preserving your data. For more details, see the [Troubleshooting Guide](../troubleshooting.md#troubleshoot-and-debug-9).

## Enabling Telemetry

Telemetry is enabled by default (`ENABLE_OPEN_TELEMETRY: true`). For configuration options, see the [Graphistry Kubernetes Telemetry Documentation](https://graphistry-admin-docs.readthedocs.io/en/latest/telemetry/kubernetes.html).

## Troubleshooting

For comprehensive troubleshooting, debugging, and verification commands covering all deployment stages, see the [Troubleshooting Guide](../troubleshooting.md).

### k3s-Specific Notes

**k3s service restart**: If the NVIDIA runtime is not being detected after editing `/etc/systemd/system/k3s.service`, restart the service:
```bash
systemctl daemon-reload
systemctl restart k3s
```

**Local-path provisioner**: k3s uses `rancher.io/local-path` as its default provisioner. If PVCs are stuck Pending, verify the local-path-provisioner pod is running:
```bash
kubectl get pods -n kube-system | grep local-path
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

# Delete namespaces
kubectl delete namespace graphistry
kubectl delete namespace postgres-operator
kubectl delete namespace dask-operator
kubectl delete namespace gpu-operator

# Inspect storage before cleanup
kubectl get pvc -n graphistry
kubectl get pv | grep graphistry
kubectl get sc | grep retain-sc

# Delete orphaned PVs (remain in Released state due to Retain policy)
kubectl get pv | grep graphistry | awk '{print $1}' | xargs kubectl delete pv

# Delete the StorageClass
kubectl delete sc retain-sc --ignore-not-found
```

### Uninstall k3s (full k3s removal)

If you want to completely remove k3s from the machine (not just Graphistry):

```bash
# Stop k3s service
systemctl stop k3s

# Kill lingering Traefik/containerd processes
/usr/local/bin/k3s-killall.sh

# Verify ports 80/443 are free
ss -tlnp | grep -E ':80|:443'
# Should be empty

# Remove k3s entirely (deletes all k3s data, containers, and networking)
/usr/local/bin/k3s-uninstall.sh

# Remove KUBECONFIG profile script
rm -f /etc/profile.d/k3s-env.sh

# Remove helm binary and local cache/repos (optional)
rm -f /usr/local/bin/helm
rm -rf ~/.cache/helm ~/.config/helm ~/.local/share/helm
```

## References

- [k3s Documentation](https://docs.k3s.io/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)
- [Graphistry Admin Docs](https://graphistry-admin-docs.readthedocs.io/)
