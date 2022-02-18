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

Create a Azure Container Registry Container principal ID and run the following command with your ACR information to create a kube secret with the ACR principal ID:

    ACR_NAME=myacr AZSUBSCRIPTION="my subscription name" SERVICE_PRINCIPAL_NAME=acrk8sprincipal CONTAINER_REGISTRY_NAME=myacrk8sregistry ./acr-bootstrap/make_acr_principal_and_create_secret.sh





> **Note:** Be sure to change the azurecontainerregistry value in values.yaml to the name of your acr as well as setting the nodeSelector value to your preferred node to deploy the cluster onto.
    
```kubectl get nodes```

once you have a node selected, run the following command and find the hostname of the node to use with the nodeSelector value:

```kubectl describe node <node name>```

and then set the nodeSelector value to the hostname of the selected node along with your acr container registry name.:


    helm install my-graphistry-chart --set azurecontainerregistry.name=<container-registry-name>.azurecr.io --set nodeSelector."kubernetes\\.io/hostname"=<node hostname> graphistry-helm/Graphistry-Helm-Chart

> **Note:** different labels can be used for the nodeSelector value, but some labels between the nodes may not be unique.