# graphistry-helm
Live helm repository and hosted documentation for production use of Graphistry with Kubernetes

For contributing to this repository as a developer, see [DEVELOP.md](DEVELOP.md)





## importing images into azure acr

> **Note:** This is an example of how to import images into an Azure Container Registry.


Set up the Azure Container Registry, get your docker login credentials, and then run the following command with your credentials and username and ACR information to import the images into the registry:


    ACR_NAME=myacr DOCKERHUB_USERNAME=mydockerhubuser DOCKERHUB_TOKEN=mydockerhubtoken ./acr-bootstrap/import-image-into-acr-from-dockerhub.sh 

Create a Azure Container Registry Container principal ID and run the following command with your ACR information to create a kube secret with the ACR principal ID:

    ACR_NAME=myacr AZSUBSCRIPTION="my subscription name" SERVICE_PRINCIPAL_NAME=acrk8sprincipal CONTAINER_REGISTRY_NAME=myacrk8sregistry ./acr-bootstrap/make_acr_principal_and_create_secret.sh



> **Note:** Be sure to change the azurecontainerregistry value in values.yaml to the name of your acr.


    helm install my-graphistry-chart --set azurecontainerregistry.name=<container-registry-name>.azurecr.io graphistry-helm/Graphistry-Helm-Chart