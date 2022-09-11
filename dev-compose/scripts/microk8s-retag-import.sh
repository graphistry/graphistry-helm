#!/bin/bash
#delete graphistry images from azure container registry

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT





retag_and_import ()
{
  OLD_IMAGE=$1
  IMAGE_TAGGED=$2


  echo "deleting image if present: image $IMAGE from $ACR_NAME"
  ( docker tag $OLD_IMAGE $IMAGE_TAGGED ) \
    && echo "Image tagged \"$IMAGE_TAGGED \" tarring...." \
    && { \
       docker save \
        $IMAGE_TAGGED \
        -o $IMAGE_TAGGED.tar \
      ; \
    }
  echo "... exporting $IMAGE_TAGGED.tar to microk8s..." \
    && microk8s ctr image import $IMAGE_TAGGED.tar \
    && echo "$IMAGE_TAGGED Image imported to microk8s" 
}







retag_and_import "docker.io/graphistry/etl-server:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:etl-server-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/etl-server-python:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:etl-server-python-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" 
retag_and_import "docker.io/graphistry/graphistry-nexus:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:graphistry-nexus-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/graphistry-pivot:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:graphistry-pivot-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/jupyter-notebook:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:jupyter-notebook-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/streamgl-gpu:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:streamgl-gpu-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/streamgl-sessions:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:streamgl-sessions-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/streamgl-vgraph-etl:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:streamgl-vgraph-etl-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/streamgl-viz:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graphistry:streamgl-viz-${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
retag_and_import "docker.io/graphistry/graph-app-kit-st:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}" "graph-app-kit-st:${APP_BUILD_TAG:-latest}-${CUDA_SHORT_VERSION:-11.0}"
# universal
retag_and_import "docker.io/graphistry/streamgl-nginx:${APP_BUILD_TAG:-latest}-universal" "graphistry:streamgl-nginx-${APP_BUILD_TAG:-latest}-universal"
retag_and_import "docker.io/graphistry/graphistry-postgres:${APP_BUILD_TAG:-latest}-universal" "graphistry:graphistry-postgres-${APP_BUILD_TAG:-latest}-universal"
retag_and_import "docker.io/graphistry/caddy:${APP_BUILD_TAG:-latest}-universal" "caddy:${APP_BUILD_TAG:-latest}-universal"

 #third-party
retag_and_import "docker.io/library/redis:${REDIS_BUILD_TAG:-6.2.7}" "redis:${REDIS_BUILD_TAG:-6.2.7}" "library"
