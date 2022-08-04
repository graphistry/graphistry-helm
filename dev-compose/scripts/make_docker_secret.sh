#!/bin/bash


#these 3 enviroment variables are required
#CONTAINER_REGISTRY_NAME
#DOCKER_USER_NAME
#DOCKER_PASSWORD







echo "Creating kubernetes image pull secret"

if [[ $CLUSTER_ENV=='skinny' ]]
then

    echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"


    [[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
        || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

    [[ ! -z "${DOCKER_USER_NAME}" ]] \
        || { echo "Set DOCKER_USER_NAME (ex: acrk8sprincipal )" && exit 1; }

    [[ ! -z "${DOCKER_PASSWORD}" ]] \
        || { echo "Set DOCKER_PASSWORD (ex: mypassword )" && exit 1; }

    if [[ ! -z $(kubectl get secrets -n graphistry  | grep "docker-secret") ]]; 
    then 
        echo "secret exist" && exit 0; 
    else  
        echo "creating secret for skinny cluster "
        kubectl create secret docker-registry docker-secret \
            --namespace graphistry \
            --docker-server=$CONTAINER_REGISTRY_NAME \
            --docker-username=$DOCKER_USER_NAME \
            --docker-password=$DOCKER_PASSWORD 
        exit 0;
    fi
elif [[ $CLUSTER_ENV=='eks-dev2' ]]
then

    echo "CONTAINER_REGISTRY_NAME: $CONTAINER_REGISTRY_NAME"


    [[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
        || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

    [[ ! -z "${DOCKER_USER_NAME_PROD}" ]] \
        || { echo "Set DOCKER_USER_NAME_PROD (ex: acrk8sprincipal )" && exit 1; }

    [[ ! -z "${DOCKER_PASSWORD_PROD}" ]] \
        || { echo "Set DOCKER_PASSWORD_PROD (ex: mypassword )" && exit 1; }

    if [[ ! -z $(kubectl get secrets -n graphistry  | grep "docker-secret-prod") ]]; 
    then 
        echo "secret exist" && exit 0; 
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