#!/bin/bash
# Import Graphistry DockerHub images into a private Azure ACR
# If you do not have read access to the Graphistry DockerHub, please contact Graphistry
# Shell most already be logged in to az aubscripton for acr

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

#### Required ###
# ACR_NAME
# DOCKERHUB_USERNAME
# DOCKERHUB_TOKEN
#### Optional ###
# APP_BUILD_TAG
# CUDA_SHORT_VERSION
###
# ex: 
# ACR_NAME=myacr DOCKERHUB_USERNAME=mydockerhubuser DOCKERHUB_TOKEN=mydockerhubtoken APP_BUILD_TAG=tag import-image-into-acr-from-dockerhub.sh
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

#####

# cuda

import_if_missing "graphistry-viz-dev:${APP_BUILD_TAG:-latest}-universal-dev"
import_if_missing "graphistry-pivot-dev:${APP_BUILD_TAG:-latest}-dev"
import_if_missing "graphistry-forge-python-dev:${APP_BUILD_TAG:-latest}-dev"

# universal
import_if_missing "graphistry-nginx-dev:${APP_BUILD_TAG:-latest}-universal-dev"
import_if_missing "graphistry-postgres:${APP_BUILD_TAG:-latest}-universal-dev"
import_if_missing "graphistry-nexus-dev:${APP_BUILD_TAG:-latest}-universal-dev"




exit 1