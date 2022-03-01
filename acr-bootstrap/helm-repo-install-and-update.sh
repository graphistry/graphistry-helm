#!/bin/bash

#set -ex
#trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
#trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT


#helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/

#helm repo update


if [[ $(helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/ | grep "exists")  ]]; 
then
  echo "Repo already exists upgrading..."
  helm repo update graphistry-helm
else
    echo "Repo does not exist adding..."
    helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
fi