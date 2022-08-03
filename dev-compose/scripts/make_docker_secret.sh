#!/bin/bash


#these 3 enviroment variables are required
#CONTAINER_REGISTRY_NAME
#DOCKER_USER_NAME
#DOCKER_PASSWORD







echo "Creating kubernetes image pull secret named docker-secret"

if [[ $CLUSTER_ENV=skinny ]]
then

echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"
echo "DOCKER_USER_NAME: $DOCKER_USER_NAME"
echo "DOCKER_PASSWORD: $DOCKER_PASSWORD"

[[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
    || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

[[ ! -z "${DOCKER_USER_NAME}" ]] \
    || { echo "Set DOCKER_USER_NAME (ex: acrk8sprincipal )" && exit 1; }

[[ ! -z "${DOCKER_PASSWORD}" ]] \
    || { echo "Set DOCKER_PASSWORD (ex: mypassword )" && exit 1; }

echo "creating secret for skinny cluster "
kubectl create secret docker-registry docker-secret \
    --namespace graphistry \
    --docker-server=$CONTAINER_REGISTRY_NAME \
    --docker-username=$DOCKER_USER_NAME \
    --docker-password=$DOCKER_PASSWORD 

else if [[ $CLUSTER_ENV=eks-dev2 ]]
then
echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"
echo "DOCKER_USER_NAME: $DOCKER_USER_NAME_PROD"
echo "DOCKER_PASSWORD: $DOCKER_PASSWORD_PROD"

[[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
    || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

[[ ! -z "${DOCKER_USER_NAME_PROD}" ]] \
    || { echo "Set DOCKER_USER_NAME_PROD (ex: acrk8sprincipal )" && exit 1; }

[[ ! -z "${DOCKER_PASSWORD_PROD}" ]] \
    || { echo "Set DOCKER_PASSWORD_PROD (ex: mypassword )" && exit 1; }


echo "creating secret for eks-dev2 cluster "
kubectl create secret docker-registry docker-secret \
    --namespace graphistry \
    --docker-server=$CONTAINER_REGISTRY_NAME \
    --docker-username=$DOCKER_USER_NAME_PROD \
    --docker-password=$DOCKER_PASSWORD_PROD 

fi






exit 0