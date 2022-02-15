#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

####these three enviroment variables are required###
#ACR_NAME
#DOCKERHUB_USERNAME
#DOCKERHUB_TOKEN
###ex: bash $ACR_NAME=myacr $DOCKERHUB_USERNAME=mydockerhubuser $DOCKERHUB_TOKEN=mydockerhubtoken import-image-into-acr-from-dockerhub.sh ###

echo "ACR_NAME: $ACR_NAME"
echo "DOCKERHUB_USERNAME: $DOCKERHUB_USERNAME"
echo "DOCKERHUB_TOKEN: $DOCKERHUB_TOKEN"

[[ ! -z "${ACR_NAME}" ]] \
    || { echo "Set ACR_NAME (ex: myacr )" && exit 1; }

[[ ! -z "${DOCKERHUB_USERNAME}" ]] \
    || { echo "Set DOCKERHUB_USERNAME (ex: mydockerhubuser )" && exit 1; }


[[ ! -z "${DOCKERHUB_TOKEN}" ]] \
    || { echo "Set DOCKERHUB_TOKEN (ex: mydockerhubtoken )" && exit 1; }

#this script will import graphistry images into ACR

echo "importing streamgl-viz image into ACR"
#graphistry/streamgl-viz:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 

az acr repository show --name ACR_NAME --image graphistry:streamgl-viz-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} || echo oops
az acr repository show --name ACR_NAME --image graphistry:fake-viz-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} || echo oops

az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:streamgl-viz-${APP_BUILD_TAG:-latest} \
  --image graphistry:streamgl-viz-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN
echo " importing streamgl-gpu image into ACR"
#graphistry/streamgl-gpu:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:streamgl-gpu-${APP_BUILD_TAG:-latest} \
  --image graphistry:streamgl-gpu-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing streamgl-sessions image into ACR"
#graphistry/streamgl-sessions:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:streamgl-sessions-${APP_BUILD_TAG:-latest} \
  --image graphistry:streamgl-sessions-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN


echo "importing streamgl-vgraph-etl image into ACR"
#graphistry/streamgl-vgraph-etl:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:streamgl-vgraph-etl-${APP_BUILD_TAG:-latest} \
  --image graphistry:streamgl-vgraph-etl-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing pivot image into ACR"
#graphistry/graphistry-pivot:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:graphistry-pivot-${APP_BUILD_TAG:-latest} \
  --image graphistry:graphistry-pivot-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo " importing forge-etl image into ACR"
#graphistry/etl-server:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:etl-server-${APP_BUILD_TAG:-latest}\
  --image graphistry:etl-server-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing forge-etl-python image into ACR"
#graphistry/etl-server-python:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:etl-server-python-${APP_BUILD_TAG:-latest} \
  --image graphistry:etl-server-python-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing nexus image into ACR"
#graphistry/graphistry-nexus:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:graphistry-nexus-${APP_BUILD_TAG:-latest} \
  --image graphistry:graphistry-nexus-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing notebook image into ACR"
#graphistry/jupyter-notebook:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} 
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:jupyter-notebook-${APP_BUILD_TAG:-latest}  \
  --image graphistry:jupyter-notebook-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0} \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing postgres image into ACR"
#graphistry/graphistry-postgres:${APP_BUILD_TAG:-latest}-universal
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:graphistry-postgres-${APP_BUILD_TAG:-latest} \
  --image graphistry:graphistry-postgres-${APP_BUILD_TAG:-latest}-universal \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing redis image into ACR"
#redis:6.0.5 #works
az acr import \
  --name $ACR_NAME \
  --source docker.io/library/redis:6.0.5 \
  --image redis:6.0.5 \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing nginx image into ACR"
#graphistry/streamgl-nginx:${APP_BUILD_TAG:-latest}-universal
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/graphistry:streamgl-nginx-${APP_BUILD_TAG:-latest} \
  --image graphistry:streamgl-nginx-${APP_BUILD_TAG:-latest}-universal \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

echo "importing caddy image into ACR" 
#graphistry/caddy:${APP_BUILD_TAG:-latest}-universal
az acr import \
  --name $ACR_NAME \
  --source docker.io/graphistry/caddy \
  --image caddy:${APP_BUILD_TAG:-latest}-universal \
  --username $DOCKERHUB_USERNAME \
  --password $DOCKERHUB_TOKEN

