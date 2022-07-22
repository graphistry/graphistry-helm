#!/bin/bash

if [[ $PRIMARY_CLUSTER ]]
then
echo "creating iam service account for primary cluster"
PRIMARY_CLUSTER=${PRIMARY_CLUSTER:-k8s-cluster}

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

eksctl create iamserviceaccount \
--cluster=$PRIMARY_CLUSTER \
--name=velero-server \
--namespace=velero \
--role-name=eks-velero-backup \
--role-only \
--attach-policy-arn=arn:aws:iam::$ACCOUNT:policy/VeleroAccessPolicy \
--approve
else
:
fi


if [[ $RECOVERY_CLUSTER ]]
then
echo "creating iam service account for recovery cluster"
eksctl create iamserviceaccount \
--cluster=$RECOVERY_CLUSTER \
--name=velero-server \
--namespace=velero \
--role-name=eks-velero-recovery \
--role-only \
--attach-policy-arn=arn:aws:iam::$ACCOUNT:policy/VeleroAccessPolicy \
--approve
else
:
fi