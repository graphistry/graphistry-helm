#!/bin/bash


#these 3 enviroment variables are required
#CONTAINER_REGISTRY_NAME
#DOCKER_USER_NAME
#DOCKER_PASSWORD
#NAMESPACE






echo "CLUSTER_NAME:" $CLUSTER_NAME
echo "checking for kubernetes image pull secret"

if [[  $CLUSTER_NAME == "skinny" ]]; then
    [[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
        || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

    [[ ! -z "${DOCKER_USER_NAME}" ]] \
        || { echo "Set DOCKER_USER_NAME (ex: acrk8sprincipal )" && exit 1; }

    [[ ! -z "${DOCKER_PASSWORD}" ]] \
        || { echo "Set DOCKER_PASSWORD (ex: mypassword )" && exit 1; }

    [[ ! -z "${NAMESPACE}" ]] \
        || { echo "Set NAMESPACE (ex: graphistry )" && exit 1; }

    if [[ ! -z $(kubectl get secrets -n $NAMESPACE  | grep "dockerhub-secret") ]]; then 
        echo "secret exist for skinny cluster" && exit 0; 
    else  
        echo "creating secret for skinny cluster "
        kubectl create secret docker-registry dockerhub-secret \
            --namespace $NAMESPACE \
            --docker-server=$CONTAINER_REGISTRY_NAME \
            --docker-username=$DOCKER_USER_NAME \
            --docker-password=$DOCKER_PASSWORD 
        exit 0;
    fi
elif [[  $CLUSTER_NAME == "eks-dev" ]]; then

    [[ ! -z "${CONTAINER_REGISTRY_NAME}" ]] \
        || { echo "Set CONTAINER_REGISTRY_NAME (ex: docker.io )" && exit 1; }

    [[ ! -z "${DOCKER_USER_NAME_PROD}" ]] \
        || { echo "Set DOCKER_USER_NAME_PROD (ex: acrk8sprincipal )" && exit 1; }

    [[ ! -z "${DOCKER_PASSWORD_PROD}" ]] \
        || { echo "Set DOCKER_PASSWORD_PROD (ex: mypassword )" && exit 1; }

    [[ ! -z "${NAMESPACE}" ]] \
        || { echo "Set NAMESPACE (ex: graphistry )" && exit 1; }

    if [[ ! -z $(kubectl get secrets -n $NAMESPACE  | grep "docker-secret-prod") ]]; then 
        echo "secret exist for eks-dev" && exit 0; 
    else  
        echo "creating secret for eks-dev cluster "
        kubectl create secret docker-registry docker-secret-prod \
            --namespace $NAMESPACE \
            --docker-server=$CONTAINER_REGISTRY_NAME \
            --docker-username=$DOCKER_USER_NAME_PROD \
            --docker-password=$DOCKER_PASSWORD_PROD 
        exit 0;
    fi
else
:
fi






exit 0