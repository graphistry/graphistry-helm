#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT



AZURE_BACKUP_SUBSCRIPTION_NAME=${AZURE_BACKUP_SUBSCRIPTION_NAME:-az-backup-subscription-name}

echo "AZURE_BACKUP_SUBSCRIPTION_NAME: $AZURE_BACKUP_SUBSCRIPTION_NAME"


[[ ! -z "${AZURE_BACKUP_SUBSCRIPTION_NAME}" ]] \
    || { echo "Set AZURE_BACKUP_SUBSCRIPTION_NAME (ex: my-az-subscription-name)" && exit 1; }



#find the name of the subscription ID
AZURE_BACKUP_SUBSCRIPTION_ID=$(az account list --query="[?name=='$AZURE_BACKUP_SUBSCRIPTION_NAME'].id | [0]" -o tsv)

#set a subscription to be the current active subscription
az account set -s $AZURE_BACKUP_SUBSCRIPTION_ID

#create a resource group for the backups storage account
AZURE_BACKUP_RESOURCE_GROUP=Velero_Backups
az group create -n $AZURE_BACKUP_RESOURCE_GROUP --location WestUS

#create the storage account with a globally unique ID since this is used for DNS
AZURE_STORAGE_ACCOUNT_ID="velero$(uuidgen | cut -d '-' -f5 | tr '[A-Z]' '[a-z]')"
az storage account create \
   --name $AZURE_STORAGE_ACCOUNT_ID \
   --resource-group $AZURE_BACKUP_RESOURCE_GROUP \
   --sku Standard_GRS \
   --encryption-services blob \
   --https-only true \
   --kind BlobStorage \
   --access-tier Hot

#create the blob container named velero
BLOB_CONTAINER=velero
az storage container create -n $BLOB_CONTAINER --public-access off --account-name $AZURE_STORAGE_ACCOUNT_ID

#obtain your Azure account subscription ID and tenant ID
AZURE_SUBSCRIPTION_ID=`az account list --query '[?isDefault].id' -o tsv`
AZURE_TENANT_ID=`az account list --query '[?isDefault].tenantId' -o tsv`

#create a service principal with the Contributor role
AZURE_CLIENT_SECRET=`az ad sp create-for-rbac --name "velero" --role "Contributor" --scopes /subscriptions/<subscription_id> --query 'password' -o tsv \
--scopes  /subscriptions/$AZURE_SUBSCRIPTION_ID[ /subscriptions/$AZURE_BACKUP_SUBSCRIPTION_ID]`

#obtain the client ID
AZURE_CLIENT_ID=`az ad sp list --display-name "velero" --query '[0].appId' -o tsv`

#create a file that contains all the relevant environment variables
cat << EOF  > ./credentials-velero
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

echo "installing velero on the client"


(. ../01-install_velero_client.sh || { echo "velero failed to install on client" && exit 1 ; })


echo "installing velero on the cluster"
#Install Velero, including all the prerequisites, on the cluster
velero install \
   --provider azure \
   --plugins velero/velero-plugin-for-microsoft-azure:v1.3.0 \
   --bucket $BLOB_CONTAINER \
   --secret-file ./credentials-velero \
   --backup-location-config resourceGroup=$AZURE_BACKUP_RESOURCE_GROUP,storageAccount=$AZURE_STORAGE_ACCOUNT_ID[,subscriptionId=$AZURE_BACKUP_SUBSCRIPTION_ID] \
   --use-restic
