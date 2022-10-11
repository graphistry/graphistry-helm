#!/bin/bash
# Import Graphistry DockerHub images into a private Azure ACR
# If you do not have read access to the Graphistry DockerHub, please contact Graphistry
# Shell most already be logged in to az aubscripton for acr

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

#### Required FOR IMPORTING GRAPHISTRY INTO ACR  ###
# ACR_NAME
# DOCKERHUB_USERNAME
# DOCKERHUB_TOKEN
#### Optional ###
# APP_BUILD_TAG
# CUDA_SHORT_VERSION
###
##REQUIRED FOR IMPORTING NGINX-INGRESS INTO ACR ###
SOURCE_REGISTRY=${SOURCE_REGISTRY:-k8s.gcr.io}
CONTROLLER_IMAGE=${CONTROLLER_IMAGE:-ingress-nginx/controller}
CONTROLLER_TAG=${CONTROLLER_TAG:-v1.2.1}
PATCH_IMAGE=${PATCH_IMAGE:-ingress-nginx/kube-webhook-certgen}
PATCH_TAG=${PATCH_TAG:-v1.1.1}
DEFAULTBACKEND_IMAGE=${DEFAULTBACKEND_IMAGE:-defaultbackend-amd64}
DEFAULTBACKEND_TAG=${DEFAULTBACKEND_TAG:-1.5} 
###
# ex: 
# ACR_NAME=myacr DOCKERHUB_USERNAME=mydockerhubuser DOCKERHUB_TOKEN=mydockerhubtoken import-image-into-acr-from-dockerhub.sh
###

echo "ACR_NAME: $ACR_NAME"
echo "DOCKERHUB_USERNAME: $DOCKERHUB_USERNAME"
echo "DOCKERHUB_TOKEN: $DOCKERHUB_TOKEN"

[[ ! -z "${ACR_NAME}" ]] \
    || { echo "Set ACR_NAME (ex: myacr )" && exit 1; }

[[ ! -z "${DOCKERHUB_USERNAME}" ]] \
    || { echo "Set DOCKERHUB_USERNAME (ex: mydockerhubuser )" && exit 1; }


[[ ! -z "${DOCKERHUB_TOKEN}" ]] \
    || { echo "Set DOCKERHUB_TOKEN (ex: mydockerhubtoken )" && exit 1; }

#####

import_if_missing ()
{
  IMAGE=$1
  OWNER=$2
  OWNER=${OWNER:-graphistry}
  echo "Importing image if missing: image $IMAGE from docker.io/$OWNER"
  ( az acr repository show --name $ACR_NAME --image "$IMAGE" &> /dev/null ) \
    && echo "Image \"$IMAGE\" found in ACR, skipping" \
    || { \
      echo "Image \"$IMAGE\" not found in ACR, importing..." \
      && az acr import \
        --name ${ACR_NAME} \
        --source "docker.io/$OWNER/$IMAGE" \
        --image $IMAGE \
        --username $DOCKERHUB_USERNAME \
        --password $DOCKERHUB_TOKEN \
      ; \
    }
  echo "... Finished handling $IMAGE"
}

import_into_acr(){
  IMAGE=$1
  TAG=$2
  echo "Importing image if missing: $IMAGE:$TAG from $SOURCE_REGISTRY"
  ( az acr repository show --name $ACR_NAME --image "$IMAGE:$TAG" &> /dev/null ) \
    && echo "Image \"$IMAGE\" found in ACR, skipping" \
    || { \
      echo "Image \"$IMAGE\" not found in ACR, importing..." \
      && az acr import \
        --name ${ACR_NAME} \
        --source "$SOURCE_REGISTRY/$IMAGE:$TAG" \
        --image $IMAGE:$TAG \
      ; \
    }
  echo "... Finished handling $IMAGE:$TAG"

}

#####

echo " Importing Graphistry images into ACR"
# cuda
import_if_missing "graphistry:etl-server-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:etl-server-python-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:graphistry-nexus-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:graphistry-pivot-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:jupyter-notebook-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:streamgl-gpu-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:streamgl-sessions-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:streamgl-vgraph-etl-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graphistry:streamgl-viz-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
import_if_missing "graph-app-kit-st:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
# universal
import_if_missing "graphistry:streamgl-nginx-${APP_BUILD_TAG:-latest}-universal"
import_if_missing "graphistry:graphistry-postgres-${APP_BUILD_TAG:-latest}-universal"
import_if_missing "caddy:${APP_BUILD_TAG:-latest}-universal"

# third-party
import_if_missing "redis:6.2.6" "library"


echo "Importing nginx ingress controller images into ACR"

import_into_acr "$CONTROLLER_IMAGE" "$CONTROLLER_TAG"
import_into_acr "$PATCH_IMAGE" "$PATCH_TAG"
import_into_acr "$DEFAULTBACKEND_IMAGE" "$DEFAULTBACKEND_TAG"

echo "importing k8s wait for container (initcontainer for graphistry) into acr "

import_if_missing "k8s-wait-for:latest" "groundnuty"


echo " importing netshoot container for dns/http optional debugging"

import_if_missing "netshoot:latest" "nicolaka"


echo "importing dask operator into acr"

SOURCE_REGISTRY=ghcr.io/dask

import_into_acr "dask-kubernetes-operator" "2022.7.0"

echo "postgres operator into acr"

SOURCE_REGISTRY=registry.developers.crunchydata.com/crunchydata

import_into_acr "crunchy-pgbackrest" "ubi8-2.40-1"

import_into_acr "crunchy-postgres" "ubi8-14.5-1"

import_into_acr "postgres-operator" "ubi8-5.2.0-0"

import_into_acr "postgres-operator-upgrade" "ubi8-5.2.0-0"

#import_into_acr "crunchy-upgrade" "ubi8-5.2.0-0"

#import_into_acr "crunchy-postgres-exporter" "ubi8-5.2.0-0"

#import_into_acr "crunchy-pgbouncer" "ubi8-1.17-1"

#import_into_acr "crunchy-pgadmin4" "ubi8-4.30-4"
SOURCE_REGISTRY=quay.io/martinhelmich

#import_into_acr "prometheus-nginxlog-exporter" "v1.9.2"