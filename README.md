# graphistry-helm
Live helm repository and hosted documentation for production use of Graphistry with Kubernetes

For contributing to this repository as a developer, see [DEVELOP.md](DEVELOP.md)





## importing images into azure acr

> **Note:** This is an example of how to import images into an Azure Container Registry.


Set up the Azure Container Registry, get your docker login credentials, and then run the following command with your credentials and username and ACR information to import the images into the registry:


    bash $ACR_NAME=myacr $DOCKERHUB_USERNAME=mydockerhubuser $DOCKERHUB_TOKEN=mydockerhubtoken acr-bootstrap/import-image-into-acr-from-dockerhub.sh 


> **Note:** Be sure to change the azurecontainerregistry value in values.yaml to the name of your acr.