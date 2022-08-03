#!/bin/bash
# Derived from https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-kubernetes

#these 4 enviroment variables are required
#AZSUBSCRIPTION
#ACR_NAME
#SERVICE_PRINCIPAL_NAME
#CONTAINER_REGISTRY_NAME

#echo "ACR_NAME: $ACR_NAME"
#echo "AZSUBSCRIPTION: $AZSUBSCRIPTION"
#echo "SERVICE_PRINCIPAL_NAME: $SERVICE_PRINCIPAL_NAME"
#echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"



[[ ! -z "${ACR_NAME}" ]] \
    || { echo "Set ACR_NAME (ex: acrk8s )" && exit 1; }

[[ ! -z "${AZSUBSCRIPTION}" ]] \
    || { echo "Set AZSUBSCRIPTION (ex: Graphistry k8s )" && exit 1; }

[[ ! -z "${SERVICE_PRINCIPAL_NAME}" ]] \
    || { echo "Set SERVICE_PRINCIPAL_NAME (ex: acrk8sprincipal )" && exit 1; }

[[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
    || { echo "Set CONTAINER_REGISTRY_NAME (ex: myacrk8sregistry.azurecr.io )" && exit 1; }

az login --service-principal --username="${SERVICE_PRINCIPAL_NAME}" --password="${CLIENT_SECRET}" --tenant="${TENANT_ID}"
az account set --subscription $AZSUBSCRIPTION

# Obtain the full registry ID for subsequent command args   
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query "id" --output tsv)
# Create the service principal with rights scoped to the registry. 
# Default permissions are for docker pull access. Modify the '--role'  
# argument value as desired:    
# acrpull:     pull only 
# acrpush:     push and pull
# owner:       push, pull, and assign roles 
PASSWORD=$(az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --scopes $ACR_REGISTRY_ID --role acrpull --query "password" --output tsv)   
USER_NAME=$(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query "[].appId" --output tsv)
# Output the service principal's credentials; use these in your services and                                                                                                                          
# applications to authenticate to the container registry.
echo "Service principal ID: $USER_NAME"
#echo "Service principal password: $PASSWORD" 


echo "Creating kubernetes image pull secret named acr-secret"

#assumes default namespace
kubectl create secret docker-registry acr-secret \
    --namespace graphistry \
    --docker-server=$CONTAINER_REGISTRY_NAME \
    --docker-username=$USER_NAME \
    --docker-password=$PASSWORD

exit 1