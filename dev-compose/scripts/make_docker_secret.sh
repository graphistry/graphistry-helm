#!/bin/bash
# Derived from https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-kubernetes

#these 3 enviroment variables are required
#CONTAINER_REGISTRY_NAME
#DOCKER_USER_NAME
#DOCKER_PASSWORD

echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"
echo "DOCKER_USER_NAME: $DOCKER_USER_NAME"
echo "DOCKER_PASSWORD: $DOCKER_PASSWORD"
echo "DOCKER_EMAIL: $DOCKER_EMAIL"


[[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
    || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

[[ ! -z "${DOCKER_USER_NAME}" ]] \
    || { echo "Set DOCKER_USER_NAME (ex: acrk8sprincipal )" && exit 1; }

[[ ! -z "${DOCKER_PASSWORD}" ]] \
    || { echo "Set DOCKER_PASSWORD (ex: myacrk8sregistry.azurecr.io )" && exit 1; }

[[ ! -z "${DOCKER_EMAIL}" ]] \
    || { echo "Set DOCKER_EMAIL (ex: service_Account@graphistry.com )" && exit 1; }

echo "Creating kubernetes image pull secret named docker-secret"

#assumes default namespace
kubectl create secret docker-registry docker-secret \
    --namespace graphistry \
    --docker-server=$CONTAINER_REGISTRY_NAME \
    --docker-username=$DOCKER_USER_NAME \
    --docker-password=$DOCKER_PASSWORD \
    --docker-email=$DOCKER_EMAIL

exit 1