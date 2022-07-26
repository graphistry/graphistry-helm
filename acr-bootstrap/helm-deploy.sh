#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

#these 9 enviroment variables are required
#SERVICE_PRINCIPAL_NAME
#SERVICE_PRINCIPAL_PASSWORD
#TENANT_ID
#RESOURCE_GROUP
#CLUSTER_NAME
#CONTAINER_REGISTRY_NAME
#NODE_NAME
#IMAGE_PULL_SECRETS
#APP_TAG
#MULTINODE

####these are required for deploying ingress-nginx controller into the cluster###
SOURCE_REGISTRY=${SOURCE_REGISTRY:-k8s.gcr.io}
CONTROLLER_IMAGE=${CONTROLLER_IMAGE:-ingress-nginx/controller}
CONTROLLER_TAG=${CONTROLLER_TAG:-v1.2.1}
PATCH_IMAGE=${PATCH_IMAGE:-ingress-nginx/kube-webhook-certgen}
PATCH_TAG=${PATCH_TAG:-v1.1.1}
DEFAULTBACKEND_IMAGE=${DEFAULTBACKEND_IMAGE:-defaultbackend-amd64}
DEFAULTBACKEND_TAG=${DEFAULTBACKEND_TAG:-1.5} 


echo "SERVICE_PRINCIPAL USERNAME: $SERVICE_PRINCIPAL_USERNAME"
echo "SERVICE_PRINCIPAL_PASSWORD: $SERVICE_PRINCIPAL_PASSWORD"
echo "TENANT_ID: $TENANT_ID"
echo "RESOURCE_GROUP: $RESOURCE_GROUP"
echo "CLUSTER_NAME: $CLUSTER_NAME"

echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"
echo "NODE_NAME: $NODE_NAME"
echo "IMAGE_PULL_SECRETS: $IMAGE_PULL_SECRETS"

echo "APP_TAG: $APP_TAG"

echo "MULTINODE: $MULTINODE"

echo "TLS: $TLS"
    
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
    || { echo "Set CONTAINER_REGISTRY_NAME (ex: myacrk8sregistry.azurecr.io )" && exit 1; }

[[ ! -z "${NODE_NAME}" ]] \
    || { echo "Set NODE_NAME (ex: acrk8s )" && exit 1; }

[[ ! -z "${IMAGE_PULL_SECRETS}" ]] \
    || { echo "Set IMAGE_PULL_SECRETS (ex: acrk8s )" && exit 1; }

[[ ! -z "${APP_TAG}" ]] \
    || { echo "Set APP_TAG (ex: v2.39.4-org_sso_k8s )" && exit 1; }

[[ ! -z "${MULTINODE}" ]] \
    || { echo "Set MULTINODE (ex: TRUE/FALSE  )" && exit 1; }

[[ ! -z "${TLS}" ]] \
    || { echo "Set TLS (ex: TRUE/FALSE )" && exit 1; }

echo "logging into az..."
az login --service-principal --username $SERVICE_PRINCIPAL_USERNAME --password $SERVICE_PRINCIPAL_PASSWORD --tenant $TENANT_ID
az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME –admin



echo "installing nvidia device plugin DaemonSet"
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml

if [[ $(helm repo add nvdp https://nvidia.github.io/k8s-device-plugin | grep "exists")  ]]; 
then
  echo "NVIDIA Device Plugin repo already exists upgrading..."
  helm repo update nvdp
else
    echo "NVIDIA Device Plugin does not exist adding..."
    helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
fi
helm install \
    --version=0.11.0 \
    --generate-name \
    --set nodeSelector."accelerator"=nvidia \
    nvdp/nvidia-device-plugin

certmanager () {
echo "installing cert-manager"
helm upgrade --install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1 \
  --set installCRDs=true \
  --set createCustomResource=true


}

ingress-nginx(){

    if [[ $(helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx | grep "exists")   ]]; 
    then
        echo "Nginx Ingress Controller Helm Repo already exists upgrading..."
        helm repo update ingress-nginx
    else
        echo "Nginx Ingress Controller Helm does not exist adding..."
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    fi
}

longhorn () {
    if [[ $(helm repo add longhorn https://charts.longhorn.io | grep "exists")   ]]; 
    then
        echo "Longhorn Helm Repo already exists upgrading..."
        helm repo update longhorn
    else
        echo "Longhorn Helm Repo does not exist adding..."
        helm repo add longhorn https://charts.longhorn.io
    fi

    kubectl create namespace longhorn-system
    echo "Deploying Longhorn"
    kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/prerequisite/longhorn-iscsi-installation.yaml -n longhorn-system
    helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system 
}




if [[ $MULTINODE=TRUE ]]
then
echo "installing Longhorn NFS "
longhorn()
else
:
fi

if [[ $TLS=TRUE ]]
then
echo "installing cert-manager "
certmanager()
else
:
fi

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
 --set containerregistry.name=$CONTAINER_REGISTRY_NAME  \
 --set nodeSelector."kubernetes\\.io/hostname"=$NODE_NAME \
 --set tag=$APP_TAG \ 
 --set imagePullSecrets=$IMAGE_PULL_SECRETS


if [[ $TLS=TRUE ]]
then
# Use Helm to deploy an NGINX ingress controller
helm upgrade -i nginx-ingress ingress-nginx/ingress-nginx \
    --version 4.1.3 \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.nodeSelector."kubernetes\.io/hostname"=$NODE_NAME \
    --set controller.image.registry=$CONTAINER_REGISTRY_NAME.azurecr.io \
    --set controller.image.image=$CONTROLLER_IMAGE \
    --set controller.image.tag=$CONTROLLER_TAG \
    --set controller.image.digest="" \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/hostname"=$NODE_NAME \
    --set controller.admissionWebhooks.patch.image.registry=$CONTAINER_REGISTRY_NAME.azurecr.io \
    --set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
    --set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
    --set controller.admissionWebhooks.patch.image.digest="" \
    --set defaultBackend.nodeSelector."kubernetes\.io/hostname"=$NODE_NAME \
    --set defaultBackend.image.registry=$CONTAINER_REGISTRY_NAME.azurecr.io \
    --set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
    --set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
    --set defaultBackend.image.digest="" \
    --set "controller.extraArgs.default-ssl-certificate=default/letsencrypt-tls" \
    --set imagePullSecrets[0].name=$IMAGE_PULL_SECRETS
else
# Use Helm to deploy an NGINX ingress controller
helm upgrade -i nginx-ingress ingress-nginx/ingress-nginx \
    --version 4.1.3 \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.nodeSelector."kubernetes\.io/hostname"=$NODE_NAME \
    --set controller.image.registry=$CONTAINER_REGISTRY_NAME.azurecr.io \
    --set controller.image.image=$CONTROLLER_IMAGE \
    --set controller.image.tag=$CONTROLLER_TAG \
    --set controller.image.digest="" \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/hostname"=$NODE_NAME \
    --set controller.admissionWebhooks.patch.image.registry=$CONTAINER_REGISTRY_NAME.azurecr.io \
    --set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
    --set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
    --set controller.admissionWebhooks.patch.image.digest="" \
    --set defaultBackend.nodeSelector."kubernetes\.io/hostname"=$NODE_NAME \
    --set defaultBackend.image.registry=$CONTAINER_REGISTRY_NAME.azurecr.io \
    --set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
    --set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
    --set defaultBackend.image.digest="" \
    --set imagePullSecrets[0].name=$IMAGE_PULL_SECRETS
fi


