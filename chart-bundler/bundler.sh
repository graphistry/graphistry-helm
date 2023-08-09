#!/bin/bash

set -e

AUX_BUNDLE_DIR=${AUX_BUNDLE_DIR:-charts-aux-bundled}
echo "AUX_BUNDLE_DIR: ${AUX_BUNDLE_DIR}"

rm -rf ${AUX_BUNDLE_DIR}

echo "checking working directory"
echo "$PWD"
mkdir -p ${AUX_BUNDLE_DIR}
cd ${AUX_BUNDLE_DIR}

# This script is used to generate a chart bundle from the forks of charts we use to suport the graphistry helm chart deployment.    

echo "gathering kube prometheus stack charts"

helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
git clone https://github.com/graphistry/prometheus-community-helm-charts.git

mkdir kube-prom-stack

cp -r prometheus-community-helm-charts/charts/kube-prometheus-stack/* kube-prom-stack

rm -rf prometheus-community-helm-charts

cd kube-prom-stack && helm dep build && cd ../


echo "gathering morpheus charts"
git clone https://github.com/graphistry/Morpheus-ai-engine


echo "gathering nvidia morpheus mlflow charts"
git clone https://github.com/graphistry/NVIDIA-morpheus-mlflow-plugin



echo "gathering dask operator charts"

helm fetch \
  --version 2023.7.2 \
  --repo https://helm.dask.org \
  --untar \
  --untardir . \
  dask-kubernetes-operator

rm -rf dask-kubernetes-operator-2023.7.2.tgz


echo "gathering cert-manager charts"

helm fetch \
  --version v1.10.1 \
  --repo https://charts.jetstack.io \
  --untar \
  --untardir . \
  cert-manager
rm -rf cert-manager-v1.10.1.tgz


echo "gathering elastic stack operator charts"

helm fetch \
  --version 2.5.0 \
  --repo https://helm.elastic.co \
  --untar \
  --untardir . \
  eck-operator
rm -rf eck-operator-2.5.0.tgz

echo "gathering NVIDIA DCGM exporter charts"


helm fetch \
  --version 3.0.0 \
  --repo https://nvidia.github.io/dcgm-exporter/helm-charts \
  --untar \
  --untardir . \
  dcgm-exporter
rm -rf dcgm-exporter-3.0.0.tgz


echo "gathering jupyterhub charts"

helm fetch \
  --version 2.0.0 \
  --repo https://jupyterhub.github.io/helm-chart/ \
  --untar \
  --untardir . \
  jupyterhub
rm -rf jupyterhub-2.0.0.tgz

echo "gathering nginx ingress controller charts"

helm fetch \
  --version 4.4.0 \
  --repo https://kubernetes.github.io/ingress-nginx \
  --untar \
  --untardir . \
  ingress-nginx
rm -rf ingress-nginx-4.4.0.tgz

echo "gathering postgres operator charts"

git clone https://github.com/CrunchyData/postgres-operator-examples

mkdir postgres-operator

cp -r postgres-operator-examples/helm/install/* postgres-operator

rm -rf postgres-operator-examples



echo "gathering argo charts"

git clone https://github.com/graphistry/argo-helm.git

mkdir argo-cd

cp -r argo-helm/charts/argo-cd/* argo-cd

rm -rf argo-helm

cd argo-cd && helm repo add redis-ha https://dandydeveloper.github.io/charts/ && helm dep build && cd ../

echo "checking charts dir ${AUX_BUNDLE_DIR}"
cd ../ && ls -alh ${AUX_BUNDLE_DIR}
du -sh ${AUX_BUNDLE_DIR}
df -h

## bundle folder xyz into asdf.tar.gz
tar -czvf ${AUX_BUNDLE_DIR}.tgz ${AUX_BUNDLE_DIR}
ls -alh ${AUX_BUNDLE_DIR}.tgz
