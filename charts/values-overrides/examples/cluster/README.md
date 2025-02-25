# Deploy a Graphistry cluster on Kubernetes

This guide provides step-by-step instructions for deploying Graphistry in a multinode environment using the K3s Kubernetes distribution.

## Prerequisites

1. Network File System (NFS): Configure the [NFS shared directory](https://graphistry-admin-docs.readthedocs.io/en/latest/install/cluster.html#step-1-configure-the-nfs-shared-directory).
3. Helm.
4. [Get Graphistry Helm charts](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#get-graphistry-helm-charts).

### For GKE
See [here](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#prerequisites) for the prerequisites, and [set up the GKE cluster](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#create-a-k8s-cluster).  Follow the steps to [get cluster credentials](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#get-cluster-credentials) and [test the cluster](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#test-the-k8s-cluster).

### For K3s

1. K3s: [Install K3s](https://docs.k3s.io/quick-start#install-script) (`curl -sfL https://get.k3s.io | sh -`)
2. If you don’t already have `kubectl` set up correctly, alias `k3s kubectl` to `kubectl` to simplify commands in this guide.
3. Setup NVIDIA container runtime as follows:
   Verify that the [container runtime](https://docs.k3s.io/advanced#alternative-container-runtime-support) supports NVIDIA GPUs.  Make sure to install 
   ```bash
   apt-get install nvidia-container-runtime
   ```
   and check/edit the file:
   ```bash
   nano /etc/systemd/system/k3s.service
   ```
   adding `--default-runtime nvidia` to the final part of the command, like this:
   ```bash
   ...
   ExecStart=/usr/local/bin/k3s \
       server --default-runtime nvidia\
   ...
   ```
   That will force to use the NVIDIA container runtime.

## Setup NFS

*Note: For GKE, it is necessary to set up an NFS server VM or use one of their native storage options (see [here](https://cloud.google.com/kubernetes-engine/docs/concepts/persistent-volumes#persistentvolumes) or [here](https://cloud.google.com/kubernetes-engine/docs/concepts/storage-overview)).*


Follow the [NFS guidelines example](https://graphistry-admin-docs.readthedocs.io/en/latest/install/cluster.html#on-the-leader-node-main-machine) to ensure the shared directory has the correct permissions.

Add the Helm repository of the NFS storage class provider:
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
```

Install the NFS storage class provider using the shared data directory path:
```bash
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=192.168.0.10 \
    --set nfs.path=/mnt/data/shared/
```

Note that the IP/address `192.168.0.10` belongs to the where the [NFS server is running](https://graphistry-admin-docs.readthedocs.io/en/latest/install/cluster.html#setup-instructions).

Verify the storage class:
```bash
kubectl get sc
```

The output should be similar to this:
```bash
NAME                   PROVISIONER                                     RECLAIMPOLICY     ...
...
nfs-client             cluster.local/nfs-subdir-external-provisioner   Delete            ...
```

## Install the Kubernetes Operators

### 1. Install the NVIDIA Operator:

*Note: For GKE follow these steps instead ([here](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#setup-the-nvidia-gpu-operator) and [here](https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke#inspect-the-nvidia-gpu-operator-optional)).*

Add the Helm repository:
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia \
    && helm repo update
```

Verify the `feature.node.kubernetes.io` flags:
```bash
kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'
```
The output should be `false`.

```bash
helm install --wait --generate-name \
    -n gpu-operator --create-namespace nvidia/gpu-operator \
    --timeout 60m \
    --set driver.version="550.144.03"
```

Wait until the operator is ready:
```bash
kubectl get pods -n gpu-operator --watch
```

Check the GPUs:
```bash
kubectl get nodes --show-labels | grep "nvidia.com/gpu.present"
```

Check the GPU lables:
```bash
kubectl get nodes -ojson | jq .items[].status.capacity | grep nvidia.com/gpu
```

### 2. Install the Dask Operator

Build the dependencies:
```bash
cd charts-aux-bundled/dask-kubernetes-operator/ && helm dep build && cd ../..
```

Install the operator:
```bash
helm upgrade -i dask-operator ./charts-aux-bundled/dask-kubernetes-operator --namespace dask-operator --create-namespace
```

Verify and wait the operator is up and running:
```bash
kubectl get pods --watch --namespace dask-operator
```

### 3. Install the Postgres Operator

Only proceed with the next command if the Postgres Operator is not already installed.
```bash
helm upgrade -i postgres-operator ./charts-aux-bundled/postgres-operator --namespace postgres-operator --create-namespace
```

Verify and wait the operator is up and running:
```bash
kubectl get pods --watch --namespace postgres-operator
```

## Deploy and Configure the Graphistry Cluster

### 1. Install the Graphistry Resources chart

The Graphistry Resources chart includes the storage class used for dynamic provisioning of volume claims for the Postgres cluster, as well as the `gak-public` and `gak-private` pods.  The remaining Graphistry pods will utilize an NFS volume that connects directly to the shared NFS directory.

Show all the values and options for this chart:
```bash
helm show values ./charts/graphistry-helm-resources
```

Install the storage class `retain-sc-cluster`:
```bash
helm upgrade -i graphistry-resources ./charts/graphistry-helm-resources -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml
```

### 2. Deploy the leader instance

Each Graphistry instance is deployed within its own Kubernetes namespace. The `leader` instance will use the `graphistry1` namespace:
```bash
kubectl create namespace graphistry1
```

Create the secrets for Docker Hub:
```bash
kubectl create secret docker-registry docker-secret-prod \
    --namespace graphistry1 \
    --docker-server=docker.io \
    --docker-username=user123 \
    --docker-password=thepassword
```

Create the secrets for [GAK (graph-app-kit)](https://github.com/graphistry/graph-app-kit), this step is optional:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gak-secret
  namespace: graphistry1
type: Opaque
stringData:
  username: gke_graphistry_user1
  password: gke_graphistry_password1
EOF
```

Verify the secrets:
```bash
kubectl get secret -n graphistry1
```

Before installing the Postgres Cluster, display the chart values using the following command:
```bash
helm show values ./charts/postgres-cluster
```

Install the Postgres Cluster using the following command; note that cluster deployment is enabled with `global.ENABLE_CLUSTER_MODE="true"`, and the current deployment is not for a follower node, meaning it will start the Postgres instance:
```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster \
  --set global.ENABLE_CLUSTER_MODE="true" \
  --set global.IS_FOLLOWER="false" \
  --namespace graphistry1 --create-namespace
```

Display the Persistent Volume Claim created for the Postgres cluster:
```bash
kubectl get pvc -n graphistry1
```

Wait until the resources are online.  The Postgres instance and host should be running almost immediately, while the initial Postgres backup may take a few seconds to come online:
```bash
kubectl get pods --watch --namespace graphistry1
```

For GKE, start the Graphistry services for the `leader` instance:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/gke/default_gke_values.yaml \
  -f ./charts/values-overrides/examples/gke/gke_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/leader.yaml \
  --namespace graphistry1 --create-namespace
```

For K3s, start the Graphistry services for the `leader` instance:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/k3s/k3s_example_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/leader.yaml \
  --namespace graphistry1 --create-namespace
```

Check Persistent Volume Claims (PVCs) for [GAK (graph-app-kit)](https://github.com/graphistry/graph-app-kit) in the `graphistry1` namespace:
```bash
kubectl get pvc -n graphistry1
```

Watch the status of pods in the `graphistry1` namespace and wait until all of them are online:
```bash
kubectl get pods --watch --namespace graphistry1
```

Get all services in the `graphistry1` namespace:
```bash
kubectl get services --namespace graphistry1
```

### 3. Get the IP address of the leader instance

Get the address for the `caddy` service.  This address will be the entry point to the main Graphistry dashboard (Nexus):
```bash
kubectl get services --namespace graphistry1 | grep caddy
```

Get the address for the `jaeger` service in the `graphistry1` namespace (use port `16686`):
```bash
kubectl get services --namespace graphistry1 | grep jaeger
```

Get the address for the `prometheus` service in the `graphistry1` namespace (use port `9090`):
```bash
kubectl get services --namespace graphistry1 | grep prometheus
```

Get the address for the `grafana` service in the `graphistry1` namespace (use port `3000`):
```bash
kubectl get services --namespace graphistry1 | grep grafana
```

### 4. Deploy the follower instances
For this example, a single follower instance will be deployed in the namespace `graphistry2`:
```bash
kubectl create namespace graphistry2
```

Create the secrets for Docker Hub:
```bash
kubectl create secret docker-registry docker-secret-prod \
    --namespace graphistry2 \
    --docker-server=docker.io \
    --docker-username=user123 \
    --docker-password=thepassword
```

Create the secrets for [GAK (graph-app-kit)](https://github.com/graphistry/graph-app-kit), this step is optional:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gak-secret
  namespace: graphistry2
type: Opaque
stringData:
  username: gke_graphistry_user1
  password: gke_graphistry_password1
EOF
```

Verify the secrets:
```bash
kubectl get secret -n graphistry1
```

Before installing the Postgres Cluster, display the chart values using the following command:
```bash
helm show values ./charts/postgres-cluster
```

Install the Postgres cluster using the following command. Note that cluster deployment is enabled with `global.ENABLE_CLUSTER_MODE="true"`. The current deployment is for a follower node, meaning the Postgres instance should be in a pending state because it will use the leader instance, and no persistent volumes should be created for the Postgres cluster:
```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster \
  --set global.ENABLE_CLUSTER_MODE="true" \
  --set global.IS_FOLLOWER="true" \
  --namespace graphistry2 --create-namespace
```

For GKE, start the Graphistry services for the `follower` instance:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/gke/default_gke_values.yaml \
  -f ./charts/values-overrides/examples/gke/gke_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/follower.yaml \
  --namespace graphistry2 --create-namespace
```

For K3s, start the Graphistry services for the `follower` instance:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/k3s_example_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/follower.yaml \
  --namespace graphistry2 --create-namespace
```

### 6. Get the IP address of the follower instance

Get the address for the `caddy` service.  This address will be the entry point to the main Graphistry dashboard (Nexus):
```bash
kubectl get services --namespace graphistry1 | grep caddy
```

## Redeploying Instances (Upgrading Helm Charts)

The Persistent Volume Claims must be reused each time the instances are redeployed.
Here is how the `leader` instance can be redeployed for GKE:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/gke/default_gke_values.yaml \
  -f ./charts/values-overrides/examples/gke/gke_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/leader.yaml \
  --set volumeName.gakPublic=$(kubectl --namespace graphistry1 get pv | grep "gak-public" | tail -n 1 | awk '{print $1;}') \
  --set volumeName.gakPrivate=$(kubectl --namespace graphistry1 get pv | grep "gak-private" | tail -n 1 | awk '{print $1;}') \
  --namespace graphistry1 --create-namespace
```

For K3s:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/k3s_example_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/leader.yaml \
  --set volumeName.gakPublic=$(kubectl --namespace graphistry1 get pv | grep "gak-public" | tail -n 1 | awk '{print $1;}') \
  --set volumeName.gakPrivate=$(kubectl --namespace graphistry1 get pv | grep "gak-private" | tail -n 1 | awk '{print $1;}') \
  --namespace graphistry1 --create-namespace
```

And here is how the `follower` instance can be redeployed for GKE:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/gke/default_gke_values.yaml \
  -f ./charts/values-overrides/examples/gke/gke_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/follower.yaml \
  --set volumeName.gakPublic=$(kubectl --namespace graphistry2 get pv | grep "gak-public" | tail -n 1 | awk '{print $1;}') \
  --set volumeName.gakPrivate=$(kubectl --namespace graphistry2 get pv | grep "gak-private" | tail -n 1 | awk '{print $1;}') \
  --namespace graphistry2 --create-namespace
```

For K3s:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
  --values ./charts/values-overrides/examples/k3s_example_values.yaml \
  -f ./charts/values-overrides/examples/cluster/cluster-storage.yaml \
  -f ./charts/values-overrides/examples/cluster/global-common.yaml \
  -f ./charts/values-overrides/examples/cluster/follower.yaml \
  --set volumeName.gakPublic=$(kubectl --namespace graphistry2 get pv | grep "gak-public" | tail -n 1 | awk '{print $1;}') \
  --set volumeName.gakPrivate=$(kubectl --namespace graphistry2 get pv | grep "gak-private" | tail -n 1 | awk '{print $1;}') \
  --namespace graphistry2 --create-namespace
```
