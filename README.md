# graphistry-helm

Company-wide Helm charts for deploying Graphistry products on Kubernetes.

See [CHANGELOG.md](CHANGELOG.md) for version history. For contributing as a developer, see [DEVELOP.md](DEVELOP.md).

## Repository Structure

```
graphistry-helm/
  charts/
    graphistry-helm/          # Graphistry product chart
    postgres-cluster/         # Crunchy Data PGO PostgreSQL cluster
    k8s-dashboard/            # Kubernetes dashboard (optional)
  charts-aux-bundled/         # Bundled auxiliary charts (PGO operator, ingress-nginx, etc.)
  chart-bundler/              # Script to fetch and bundle auxiliary charts
  docs/                       # Sphinx documentation (ReadTheDocs)
  charts/values-overrides/
    examples/
      k3s/                    # k3s deployment guide and example values
      gke/                    # GKE deployment guide and example values
      tanzu/                  # Tanzu/vSphere deployment guide and example values
      cluster/                # Multi-node cluster mode values
      troubleshooting.md      # Comprehensive troubleshooting guide (11 stages)
```

## Quick Start

Each platform has a dedicated deployment guide with step-by-step instructions:

- [k3s Deployment Guide](charts/values-overrides/examples/k3s/README.md)
- [GKE Deployment Guide](charts/values-overrides/examples/gke/README.md)
- [Tanzu/vSphere Deployment Guide](charts/values-overrides/examples/tanzu/README.md)
- [Troubleshooting Guide](charts/values-overrides/examples/troubleshooting.md)

## Prerequisites

1. **Kubernetes cluster** with GPU nodes (k3s, GKE, Tanzu, EKS, AKS)
2. **NVIDIA GPU Operator** or device plugin installed on GPU nodes
3. **Helm 3+**
4. **Docker Hub access** to Graphistry images (contact [Graphistry Support](https://www.graphistry.com/support))

## Deployment Tiers

Graphistry v2.50.1+ supports four deployment tiers via `global.tier` in your values file:

| Tier | Description | GPU Required |
|------|-------------|:------------:|
| `platform` | `postgres` + `nexus`. Auth provider, foundation for Louie or other integrations. | No |
| `analytics` | `platform` + GPU compute, ETL processing, GFQL graph queries, public API access. | Yes |
| `viz` | `analytics` + interactive graph visualization with WebGL rendering and real-time GPU layout. | Yes |
| `full` | `viz` + Streamlit dashboards, Jupyter notebooks, and investigation tools. **Default tier**. | Yes |

Each tier includes all capabilities of the previous tiers. See the platform deployment guides for the full services and PVCs per tier tables.

## Install

```bash
# 1. Bundle auxiliary charts (PGO operator, ingress-nginx, etc.)
bash chart-bundler/bundler.sh

# 2. Create namespace and Docker Hub secret
kubectl create namespace graphistry
kubectl create secret docker-registry docker-secret-prod \
    --namespace graphistry \
    --docker-server=docker.io \
    --docker-username=<DOCKERHUB_USER> \
    --docker-password=<DOCKERHUB_TOKEN>

# 3. Install PGO operator
helm install pgo ./charts-aux-bundled/pgo -n postgres-operator --create-namespace

# 4. Install PostgreSQL cluster
helm install pg-cluster ./charts/postgres-cluster -n graphistry

# 5. Install Graphistry
helm install g-chart ./charts/graphistry-helm \
    --values ./charts/values-overrides/examples/<platform>/<platform>_example_values.yaml \
    --namespace graphistry
```

Replace `<platform>` with `k3s`, `gke`, or `tanzu`. See the platform-specific README for StorageClass setup, GPU operator installation, and other prerequisites.

## CUDA and Driver Support

Graphistry v2.50.1+ uses RAPIDS 26.02 and publishes two image flavors:

| Build | RAPIDS | CUDA Toolkit | Recommended Min Driver |
|-------|--------|-------------|----------------------|
| `cuda.version: "12"` | 26.02 | 12.9.1 | R575+ (575.51.03+) |
| `cuda.version: "13"` | 26.02 | 13.1.0 | R590+ (590.44.01+) |

See the [RAPIDS Platform Support](https://docs.rapids.ai/platform-support/) matrix and [NVIDIA CUDA Toolkit Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/) for the full driver compatibility matrix.

## Private Docker Image Repositories

We recommend using a private repository to avoid rate-limiting and improve security:

* Setup a free [DockerHub account](https://hub.docker.com/) and generate a token for use as a service account
* Notify Graphistry of the DockerHub account ID and get confirmation of read-access to the Graphistry Docker images
* Pick one of the instructions below

### Azure Container Registry (ACR)

#### Option 1 (Recommended): Automatic - Azure Pipelines

* Fork this repository
* In Azure Pipelines, connect to your forked repository and load pipeline [azure-pipelines.acr-mirror.yml](acr-bootstrap/azure-pipelines.acr-mirror.yml)
* In the Azure Pipelines UI, add pipeline variables as defined in the script
* Run the pipeline

Updates:
* Update the pipeline by pulling the latest changes of this repository into your fork
* Get new Graphistry versions by updating variable `GRAPHISTRY_VERSION` and rerunning the pipeline

#### Option 2: Manual

* Set up the Azure Container Registry
* Login to Azure: `az login`
* Run:
```bash
APP_BUILD_TAG=latest ACR_NAME=myacr DOCKERHUB_USERNAME=mydockerhubuser DOCKERHUB_TOKEN=mydockerhubtoken ./acr-bootstrap/import-image-into-acr-from-dockerhub.sh
```

### Azure Kubernetes Secrets

Create an Azure Container Registry principal ID by running the following command with your ACR information:

    ACR_NAME=myacr AZSUBSCRIPTION="my subscription name" SERVICE_PRINCIPAL_NAME=acrk8sprincipal CONTAINER_REGISTRY_NAME=myacrk8sregistry ./acr-bootstrap/make_acr_principal_and_create_secret.sh

### Azure: Setting the Node Selector and ACR Registry

> **Note:** Be sure to change the azurecontainerregistry value in values.yaml to the name of your ACR as well as setting the nodeSelector value to your preferred node to deploy the cluster onto.

```bash
kubectl get nodes
```

Once you have a node selected, run the following command and find the hostname of the node to use with the nodeSelector value:

```bash
kubectl describe node <node name>
```

Then set the nodeSelector value to the hostname of the selected node along with your ACR container registry name:

```bash
helm upgrade -i my-graphistry-chart graphistry-helm/Graphistry-Helm-Chart \
    --set azurecontainerregistry.name=<container-registry-name>.azurecr.io \
    --set nodeSelector."kubernetes\\.io/hostname"=<node hostname> \
    --set domain=<FQDN or node external IP ex: example.com> \
    --set imagePullSecrets=<secrets_name>
```

> **Note:** Different labels can be used for the nodeSelector value, but some labels between the nodes may not be unique.

### Any Other Kubernetes Cluster

    kubectl create secret docker-registry docker-secret-prod \
    --namespace graphistry \
    --docker-server=<CONTAINER_REGISTRY_NAME>.azurecr.io \
    --docker-username=<Docker username> \
    --docker-password=<Docker password>

## Documentation

- [ReadTheDocs](https://graphistry-helm.readthedocs.io/) (Sphinx docs)
- [Troubleshooting Guide](charts/values-overrides/examples/troubleshooting.md) (11 deployment stages, verified commands, sample outputs)
- [StorageClass Configuration](docs/source/configure-storageclass.rst)
- [Telemetry Guide](https://graphistry-admin-docs.readthedocs.io/en/latest/telemetry/kubernetes.html)
