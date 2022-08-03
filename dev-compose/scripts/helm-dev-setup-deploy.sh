#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT





echo "APP_TAG": $APP_TAG

echo "MULTINODE": $MULTINODE

echo "TLS": $TLS

[[ ! -z "${MULTINODE}" ]] \
    || { echo "Set MULTINODE (ex: TRUE/FALSE  )" && exit 1; }

[[ ! -z "${TLS}" ]] \
    || { echo "Set TLS (ex: true/false )" && exit 1; }

[[ ! -z "${APP_TAG}" ]] \
    || { echo "Set APP_TAG (ex: v2.39.4-org_sso_k8s )" && exit 1; }




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
}


if [[ $MULTINODE=='TRUE']]
then
echo "installing Longhorn NFS "
longhorn()
kubectl create namespace longhorn-system
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/prerequisite/longhorn-iscsi-installation.yaml -n longhorn-system
helm upgrade -i longhorn longhorn/longhorn --namespace longhorn-system 
else
:
fi

if [[ $TLS=='true' ]]
then
echo "installing cert-manager"
certmanager()
echo "installing nginx ingress controller with ssl"
helm upgrade -i --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set "controller.extraArgs.default-ssl-certificate=default/letsencrypt-tls"
else
echo "installing nginx ingress controller"
helm upgrade -i --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace 
fi




exit 0