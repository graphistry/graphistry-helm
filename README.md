# graphistry-helm
Run Graphistry in Kubernetes using this live helm repository and supporting automation scripts & documentation 

For contributing to this repository as a developer, see [DEVELOP.md](DEVELOP.md)

## Private docker image repositories

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

## Kubernetes secrets

### Azure

Create a Azure Container Registry Container principal ID by running the following command with your ACR information to create a kube secret with the ACR principal ID(This script assumes a default namespace, to change, edit the script):

    ACR_NAME=myacr AZSUBSCRIPTION="my subscription name" SERVICE_PRINCIPAL_NAME=acrk8sprincipal CONTAINER_REGISTRY_NAME=myacrk8sregistry ./acr-bootstrap/make_acr_principal_and_create_secret.sh

### Any other Kubernetes cluster (assumes a default namespace)

    kubectl create secret docker-registry acr-secret \
    --namespace default \
    --docker-server=<CONTAINER_REGISTRY_NAME>.azurecr.io \
    --docker-username=<Docker username> \
    --docker-password=<Docker password> 

## Add gpu daemonset to cluster
> **Note:** Be sure to add the nvidia device plugin daemonset to the cluster before deployment. \
```kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml```

once daemonset has been installed and started
if successful will see nvidia.com/gpu in nodes capacity here \
```kubectl get nodes -ojson | jq .items[].status.capacity```

## install Nginx ingress controller
> **Note:** Be sure to add the nginx ingress controller to the cluster before deployment. \
```helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace```

## install Longhorn NFS
> **Note:** Be sure to add Longhorn  to the cluster before deployment. \
```helm repo add longhorn https://charts.longhorn.io ``` \
```helm repo update``` \
```kubectl create namespace longhorn-system``` \ 
```kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/prerequisite/longhorn-iscsi-installation.yaml -n longhorn-system``` \
```helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system ```


## Setting the node selector and the acr container registry for deployment 
> **Note:** Be sure to change the azurecontainerregistry value in values.yaml to the name of your acr as well as setting the nodeSelector value to your preferred node to deploy the cluster onto.
    
```kubectl get nodes```

once you have a node selected, run the following command and find the hostname of the node to use with the nodeSelector value:

```kubectl describe node <node name>```

and then set the nodeSelector value to the hostname of the selected node along with your acr container registry name.:


    helm upgrade -i my-graphistry-chart graphistry-helm/Graphistry-Helm-Chart \
     --set azurecontainerregistry.name=<container-registry-name>.azurecr.io \
     --set nodeSelector."kubernetes\\.io/hostname"=<node hostname> \ 
     --set domain = <FQDN or node external IP ex: example.com> \
     --set imagePullSecrets=<secrets_name>  (has to go last) 
> **Note:** different labels can be used for the nodeSelector value, but some labels between the nodes may not be unique.

[ReadTheDocs](docs/source/index.rst)
