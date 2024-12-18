# Deploy a Graphistry k8s cluster using GKE
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
      --machine-type "n1-highmem-4" \
      --accelerator "type=nvidia-tesla-t4,count=1,gpu-driver-version=default" \
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

To properly install the NVIDIA GPU Operator in Kubernetes, you must first check the value of the `nfd.enabled` label on your cluster nodes.  This label is used to determine whether Node Feature Discovery (NFD) is enabled, which is important because the GPU Operator depends on certain hardware features being correctly discovered.  Run the following command to retrieve the value of `nfd.enabled`:
```bash
kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'
```

If the result includes `nfd.enabled=true`, it indicates that NFD is enabled on the nodes.  In this case, you need to explicitly disable NFD during the GPU Operator installation: so if `nfd.enabled` is `true` then add `--set nfd.enabled=false` to the next `helm install` command:
```bash
helm install --wait --generate-name \
    -n gpu-operator \
    nvidia/gpu-operator \
    --version=v24.9.0 \
    --set hostPaths.driverInstallDir=/home/kubernetes/bin/nvidia \
    --set toolkit.installDir=/home/kubernetes/bin/nvidia \
    --set cdi.enabled=true \
    --set cdi.default=true \
    --set driver.enabled=false \
    --timeout 60m
```

Notes:
1. Using the version `v24.9.0` helps avoid certain issues with the GPU Operator, as discussed in https://github.com/NVIDIA/gpu-operator/issues/901 (see `--set driver.upgradePolicy.autoUpgrade=false`).
2. The recomended driver version (e.g. `--set driver.version="550.127.08"`) can be found in the official [NVIDIA GPU Operator Matrix](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/platform-support.html#gpu-operator-component-matrix).

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
Here you can use your Docker Hub user and password, your account must have access to the official Graphistry docker images.
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
helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=LoadBalancer
```

Verify the `EXTERNAL-IP` (this will be used to access to the cluster from the browser):
```bash
kubectl get service --namespace ingress-nginx ingress-nginx-controller --output wide --watch
```

## Create the storage class
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: retain-sc-graphistry
provisioner: pd.csi.storage.gke.io
volumeBindingMode: WaitForFirstConsumer
EOF
```

## Install Postgres Operator
```bash
helm upgrade -i postgres-operator ./charts-aux-bundled/postgres-operator --namespace postgres-operator --create-namespace
```

## Install Postgres Cluster
```bash
helm show values ./charts/postgres-cluster
```

Install the cluster chart using this command:
```bash
helm upgrade -i postgres-cluster ./charts/postgres-cluster --set global.provisioner="pd.csi.storage.gke.io" --namespace graphistry --create-namespace
```

Wait until the pods are online (`postgres-repo-host-*` should be running):
```bash
kubectl get pods --watch -n graphistry
```

The output should be similar to:
```bash
NAME                        READY   STATUS    RESTARTS   AGE
postgres-instance1-5lkd-0   0/4     Pending   0          4m43s
postgres-repo-host-0        2/2     Running   0          4m43s
```

The `postgres-instance` will run later (once we start the `graphistry-resources` chart).

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

## Install Graphistry Resources
```bash
helm show values ./charts/graphistry-helm-resources
```

Install the `graphistry-resources` chart using this command:
```bash
helm upgrade -i graphistry-resources ./charts/graphistry-helm-resources  \
    --set global.provisioner="pd.csi.storage.gke.io" \
    --namespace graphistry --create-namespace
```

Wait until the resources are online (`postgres-instance1-*` and `postgres-backup-*` should be running after some seconds):
```bash
kubectl get pods --watch -n graphistry
```

## Install Graphistry
You can set the CUDA and Graphistry versions by editing `./charts/values-overrides/examples/gke/gke_values.yaml`:
```yaml
cuda:
  version: "11.8" #cuda version

global:  ## global settings for all charts
  tag: v2.41.15
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
    --values ./charts/values-overrides/examples/gke/default_gke_values.yaml \
    -f ./charts/values-overrides/examples/gke/gke_values.yaml \
    --namespace graphistry --create-namespace
```

Wait unilt all the pods are running and completed:
```bash
kubectl get pods --watch -n graphistry
```

It's possible to get the public cluster address using this command (this IP is the ADDRESS` of the `ingress-controller`):
```bash
kubectl get ingress -n graphistry
```

Once you open Graphistry in the browser, create an account for the admin user with the email and password.

## Update Graphistry deployment
In case we want to change some values in `../gke_values.yaml` reusing the volume names:
```bash
helm upgrade -i g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/gke/default_gke_values.yaml \
    --set volumeName.dataMount=$(kubectl get pv -n graphistry | grep "data-mount" | tail -n 1 | awk '{print $1;}') \
    --set volumeName.localMediaMount=$(kubectl get pv -n graphistry | grep "local-media-mount" | tail -n 1 | awk '{print $1;}') \
    --set volumeName.gakPublic=$(kubectl get pv -n graphistry | grep "gak-public" | tail -n 1 | awk '{print $1;}') \
    --set volumeName.gakPrivate=$(kubectl get pv -n graphistry | grep "gak-private" | tail -n 1 | awk '{print $1;}') \
    -f ./charts/values-overrides/examples/gke/gke_values.yaml \
    --namespace graphistry --create-namespace
```

Check the resources using this command:
```bash
kubectl get pods --watch -n graphistry
```

## Enabling Telemetry
See [Graphistry Telemetry for Kubernetes](https://github.com/graphistry/graphistry-cli/blob/master/docs/telemetry/kubernetes.md).

## Delete k8s cluster
Delete the Graphistry chart:
```bash
helm uninstall g-chart -n graphistry
```

Delete the `graphistry-resources` chart:
```bash
helm uninstall graphistry-resources -n graphistry
```

Delete the `postgres-cluster` chart:
```bash
helm uninstall postgres-cluster -n graphistry
```

Delete the `postgres-operator` chart:
```bash
helm uninstall postgres-operator -n postgres-operator
```

Delete the `dask-operator` chart:
```bash
helm uninstall dask-operator -n dask-operator
```

Delete the docker registry secrets:
```bash
kubectl delete secret docker-secret-prod -n graphistry
```

Print all namespaces:
```bash
kubectl get ns
```

Verify that no pods are running for the `graphistry` namespace using this command:
```bash
kubectl get pods --watch --namespace graphistry
```

Delete the `dask-operator` namespace:
```bash
kubectl delete ns dask-operator
```

Delete the `postgres-operator` namespace:
```bash
kubectl delete ns postgres-operator
```

Delete the `graphistry` namespace:
```bash
kubectl delete namespace graphistry
```

Also, it's possible to delete the K8s cluster:
```bash
gcloud container clusters delete demo-cluster --zone us-central1-a
```

## Utility and troubleshooting commands

### caddy-ingress
```bash
kubectl describe ingress caddy-ingress-graphistry -n graphistry
kubectl describe $(kubectl get pods -o name | grep caddy)

# print the logs
kubectl -n graphistry logs $(kubectl -n graphistry get pods -o name | grep caddy) -f
```

### nexus
```bash
# print the logs
kubectl logs $(kubectl get pods -o name -n graphistry | grep nexus) -n graphistry -f

# get into the container
kubectl exec -i -t $(kubectl get pods -o name -n graphistry | grep nexus) -n graphistry --container nexus -- /bin/bash
```

### streamgl-gpu
```bash
kubectl describe $(kubectl get pods -o name -n graphistry | grep streamgl-gpu) -n graphistry

# print the logs
kubectl logs $(kubectl get pods -o name -n graphistry | grep streamgl-gpu) -n graphistry -f
```

### forge-etl-python
```bash
kubectl describe $(kubectl get pods -o name -n graphistry | grep forge-etl-python) -n graphistry

# print the logs
kubectl logs $(kubectl get pods -o name -n graphistry | grep forge-etl-python) -n graphistry -f

# get into the container
kubectl exec -i -t $(kubectl get pods -o name -n graphistry | grep forge-etl-python) -n graphistry --container forge-etl-python -- /bin/bash
```

### dask-cuda
```bash
kubectl describe $(kubectl get pods -o name -n graphistry | grep dask-cuda) -n graphistry

# print the logs
kubectl logs $(kubectl get pods -o name  -n graphistry | grep dask-cuda) -n graphistry -f
```

### pivot
If this service work, feel free to kill the pod and start a new instance, that should solve the glitch.

```bash
kubectl describe $(kubectl get pods -o name -n graphistry | grep pivot) -n graphistry

# print the logs
kubectl logs $(kubectl get pods -o name  -n graphistry | grep pivot)  -n graphistry -f
```
