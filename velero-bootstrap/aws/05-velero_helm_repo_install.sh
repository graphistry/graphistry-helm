#!/bin/bash
echo "adding velero helm repo"


if [[ $(helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-chart | grep "exists")   ]]; 
then
    echo "Velero Helm Repo already exists upgrading..."
    helm repo update vmware-tanzu
else
    echo "Velero Helm Repo does not exist adding..."
    helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-chart
fi