#!/bin/bash


#these 3 enviroment variables are required
#CONTAINER_REGISTRY_NAME
#DOCKER_USER_NAME
#DOCKER_PASSWORD






echo "CLUSTER_NAME:" $CLUSTER_NAME
echo "checking for kubernetes image pull secret"

if [[ $CLUSTER_NAME=='skinny' ]]; then
    [[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
        || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

    [[ ! -z "${DOCKER_USER_NAME}" ]] \
        || { echo "Set DOCKER_USER_NAME (ex: acrk8sprincipal )" && exit 1; }

    [[ ! -z "${DOCKER_PASSWORD}" ]] \
        || { echo "Set DOCKER_PASSWORD (ex: mypassword )" && exit 1; }

    if [[ ! -z $(kubectl get secrets -n graphistry  | grep "dockerhub-secret") ]]; then 
        echo "secret exist for skinny cluster" && exit 0; 
    else  
        echo "creating secret for skinny cluster "
        kubectl create secret docker-registry dockerhub-secret \
            --namespace graphistry \
            --docker-server=$CONTAINER_REGISTRY_NAME \
            --docker-username=$DOCKER_USER_NAME \
            --docker-password=$DOCKER_PASSWORD 
        exit 0;
    fi
elif [[ $CLUSTER_NAME=='eks-dev2' ]]; then

    [[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
        || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

    [[ ! -z "${DOCKER_USER_NAME_PROD}" ]] \
        || { echo "Set DOCKER_USER_NAME_PROD (ex: acrk8sprincipal )" && exit 1; }

    [[ ! -z "${DOCKER_PASSWORD_PROD}" ]] \
        || { echo "Set DOCKER_PASSWORD_PROD (ex: mypassword )" && exit 1; }

    if [[ ! -z $(kubectl get secrets -n graphistry  | grep "docker-secret-prod") ]]; then 
        echo "secret exist for eks-dev2" && exit 0; 
    else  
        echo "creating secret for eks-dev2 cluster "
        kubectl create secret docker-registry docker-secret-prod \
            --namespace graphistry \
            --docker-server=$CONTAINER_REGISTRY_NAME \
            --docker-username=$DOCKER_USER_NAME_PROD \
            --docker-password=$DOCKER_PASSWORD_PROD 
        exit 0;
    fi
else
:
fi






exit 0