#!/bin/bash







echo "APP_TAG": $APP_TAG

echo "MULTINODE": $MULTINODE

echo "TLS": $TLS

[[ ! -z "${MULTINODE}" ]] \
    || { echo "Set MULTINODE (ex: true/false  )" && exit 1; }

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
if [[ ! -z $(helm repo add longhorn https://charts.longhorn.io | grep "exists")   ]]; 
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


if [[ $MULTINODE == "true" ]]
then
  if [[ ! -z $(kubectl get ns | grep "longhorn-system")   ]]; 
  then
    echo "longhorn already exists"
  else
    echo " installing longhorn on the cluster"
    longhorn
  fi
else
  echo "multinode is off"
fi


if [[ $TLS == "true" ]];
then
  if [[ ! -z $(kubectl get ns | grep "cert-manager")   ]]; 
  then
    echo "cert-manager already exists"
  else
    echo " installing cert-manager on the cluster"
    certmanager
  fi

  if [[ ! -z $(kubectl get ns | grep "ingress-nginx") ]] && [[ ! -z  $(helm get all ingress-nginx -n ingress-nginx | grep "default-ssl-certificate: graphistry/letsencrypt-tls") ]]; 
  then
    echo "ingress-nginx with TLS already exists";
  else
    echo "installing nginx ingress controller with TLS"
    helm upgrade -i --install ingress-nginx ingress-nginx \
      --repo https://kubernetes.github.io/ingress-nginx \
      --namespace ingress-nginx --create-namespace \
      --set "controller.extraArgs.default-ssl-certificate=graphistry/letsencrypt-tls" 

  fi

else

  if [[ ! -z $(kubectl get ns | grep "ingress-nginx")   ]] && [[ -z  $(helm get all ingress-nginx -n ingress-nginx | grep "default-ssl-certificate: graphistry/letsencrypt-tls") ]]; 
  then
    echo "ingress-nginx already exists without TLS";
  else
    echo "installing nginx ingress controller without TLS"
    helm upgrade -i --install ingress-nginx ingress-nginx \
      --repo https://kubernetes.github.io/ingress-nginx \
      --namespace ingress-nginx --create-namespace 
  fi

fi




