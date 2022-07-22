#!/bin/bash
#PRIMARY_CLUSTER=${PRIMARY_CLUSTER:-k8s-cluster}
#RECOVERY_CLUSTER=${RECOVERY_CLUSTER:-k8s-cluster-recovery}
#ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

if [[ $PRIMARY_CLUSTER ]]
then
echo " associating OIDC with primary cluster"
eksctl utils associate-iam-oidc-provider --region=$REGION --cluster=$PRIMARY_CLUSTER --approve

echo "creating iam service account for primary cluster"


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
echo " associating OIDC with recovery cluster"
eksctl utils associate-iam-oidc-provider --region=$REGION --cluster=$RECOVERY_CLUSTER --approve
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