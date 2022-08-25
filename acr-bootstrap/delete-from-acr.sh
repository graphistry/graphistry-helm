#!/bin/bash
#delete graphistry images from azure container registry

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT



echo "ACR_NAME: $ACR_NAME"



[[ ! -z "${ACR_NAME}" ]] \
    || { echo "Set ACR_NAME (ex: myacr )" && exit 1; }



delete_if_present ()
{
  IMAGE=$1


  echo "deleting image if present: image $IMAGE from $ACR_NAME"
  ( az acr repository show --name $ACR_NAME --image "$IMAGE" &> /dev/null ) \
    && echo "Image \"$IMAGE\" found in ACR, deleting.." \
    && { \
       az acr repository delete \
        --name ${ACR_NAME} \
        --image $IMAGE \
      ; \
    }
  echo "... Finished deleting $IMAGE"
}







delete_if_present "graphistry:etl-server-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:etl-server-python-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:graphistry-nexus-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:graphistry-pivot-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:jupyter-notebook-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:streamgl-gpu-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:streamgl-sessions-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:streamgl-vgraph-etl-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graphistry:streamgl-viz-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
delete_if_present "graph-app-kit-st:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
# universal
delete_if_present "graphistry:streamgl-nginx-${APP_BUILD_TAG:-latest}-universal"
delete_if_present "graphistry:graphistry-postgres-${APP_BUILD_TAG:-latest}-universal"
delete_if_present "caddy:${APP_BUILD_TAG:-latest}-universal"

# third-party
#delete_if_present "redis:${REDIS_BUILD_TAG:-6.2.6}" "library"
