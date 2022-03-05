#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

#these 8 enviroment variables are required
#SERVICE_PRINCIPAL_NAME
#SERVICE_PRINCIPAL_PASSWORD
#TENANT_ID
#RESOURCE_GROUP
#CLUSTER_NAME
#CONTAINER_REGISTRY_NAME
#NODE_NAME
#IMAGE_PULL_SECRETS
#APP_TAG

echo "SERVICE_PRINCIPAL USERNAME: $SERVICE_PRINCIPAL_USERNAME"
echo "SERVICE_PRINCIPAL_PASSWORD: $SERVICE_PRINCIPAL_PASSWORD"
echo "TENANT_ID: $TENANT_ID"
echo "RESOURCE_GROUP: $RESOURCE_GROUP"
echo "CLUSTER_NAME: $CLUSTER_NAME"

echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"
echo "NODE_NAME: $NODE_NAME"
echo "IMAGE_PULL_SECRETS: $IMAGE_PULL_SECRETS"

echo "APP_TAG": $APP_TAG
    
[[ ! -z "${SERVICE_PRINCIPAL_USERNAME}" ]] \
    || { echo "Set SERVICE_PRINCIPAL_USERNAME (ex: myserviceprincipalusername )" && exit 1; }
    
[[ ! -z "${SERVICE_PRINCIPAL_PASSWORD}" ]] \
    || { echo "Set SERVICE_PRINCIPAL_PASSWORD (ex: myserviceprincipalpassword )" && exit 1; }
    
[[ ! -z "${TENANT_ID}" ]] \
    || { echo "Set TENANT_ID (ex: mytenantid )" && exit 1; }
    
[[ ! -z "${RESOURCE_GROUP}" ]] \
    || { echo "Set RESOURCE_GROUP (ex: myresourcegroup )" && exit 1; }
    
[[ ! -z "${CLUSTER_NAME}" ]] \
    || { echo "Set CLUSTER_NAME (ex: myclustername )" && exit 1; }

[[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
    || { echo "Set CONTAINER_REGISTRY_NAME (ex: myacrk8sregistry )" && exit 1; }

[[ ! -z "${NODE_NAME}" ]] \
    || { echo "Set NODE_NAME (ex: acrk8s )" && exit 1; }

[[ ! -z "${IMAGE_PULL_SECRETS}" ]] \
    || { echo "Set IMAGE_PULL_SECRETS (ex: acrk8s )" && exit 1; }

[[ ! -z "${APP_TAG}" ]] \
    || { echo "Set APP_TAG (ex: v2.39.4-org_sso_k8s )" && exit 1; }

echo "logging into az..."
az login --service-principal --username $SERVICE_PRINCIPAL_USERNAME --password $SERVICE_PRINCIPAL_PASSWORD --tenant $TENANT_ID
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME –admin



echo "installing nvidia device plugin DaemonSet"
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml



echo "installing nginx controller"
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace



echo "installing Longhorn NFS"

if [[ $(helm repo add longhorn https://charts.longhorn.io | grep "exists")  ]]; 
then
  echo "Longhorn Helm Repo already exists upgrading..."
  helm repo update longhorn
else
    echo "Longhorn Helm Repo does not exist adding..."
    helm repo add longhorn https://charts.longhorn.io
fi

kubectl create namespace longhorn-system
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/prerequisite/longhorn-iscsi-installation.yaml -n longhorn-system
helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system 



echo "deploying graphistry cluster"

if [[ $(helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/ | grep "exists")  ]]; 
then
  echo "Graphistry Helm Repo already exists upgrading..."
  helm repo update graphistry-helm
else
    echo "Graphistry Helm Repo does not exist adding..."
    helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
fi

helm upgrade -i my-graphistry-chart graphistry-helm/Graphistry-Helm-Chart \
 --set azurecontainerregistry.name=$CONTAINER_REGISTRY_NAME.azurecr.io  \
 --set nodeSelector."kubernetes\\.io/hostname"=$NODE_NAME \
 --set tag=$APP_TAG \ 
 --set imagePullSecrets=$IMAGE_PULL_SECRETS
