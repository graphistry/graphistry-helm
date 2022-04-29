#!/bin/bash
#checks if secret is created and if not starts script to create it 
if [[ ! -z $(kubectl get secrets -n graphistry  | grep "acr-secret") ]]; then 
              echo "secret exist" && exit 0; 
            else  ./make_secret.sh; fi