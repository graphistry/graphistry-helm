#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

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
echo "installing Longhorn NFS "
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
 --set azurecontainerregistry.name=$CONTAINER_REGISTRY_NAME.azurecr.io  \
 if [[ $NODE_NAME ]]
then
 --set nodeSelector."kubernetes\\.io/hostname"=$NODE_NAME \
fi
 --set tag=$APP_TAG \ 
 --set imagePullSecrets=$IMAGE_PULL_SECRETS


helm upgrade -i --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
if [[ $MULTINODE=TRUE ]]
then
  --set "controller.extraArgs.default-ssl-certificate=default/letsencrypt-tls"
fi
