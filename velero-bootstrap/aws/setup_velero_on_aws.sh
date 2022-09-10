#!/bin/bash

set -ex
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT


#this script must be run from velero-bootstrap/aws directory
#the following 7 env vars are necessary to run this script

#VERSION
#COMPANY_NAME
#BUCKET
#REGION
#PRIMARY_CLUSTER
#RECOVERY_CLUSTER ##OPTIONAL IF THERE IS A RECOVERY CLUSTER
#ACCOUNT

VERSION=${VERSION:-v1.9.0}
COMPANY_NAME=${COMPANY_NAME:-graphistry}
BUCKET=${BUCKET:-$COMPANY_NAME-eks-velero-backups}
REGION=${REGION:-us-east-2}
PRIMARY_CLUSTER=${PRIMARY_CLUSTER:-k8s-cluster-managed}
RECOVERY_CLUSTER=${RECOVERY_CLUSTER}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)


echo "VELERO VERSION: $VERSION"
echo "COMPANY_NAME: $COMPANY_NAME"
echo "BUCKET: $BUCKET"
echo "REGION: $REGION"
echo "PRIMARY_CLUSTER: $PRIMARY_CLUSTER"
echo "RECOVERY_CLUSTER: $RECOVERY_CLUSTER"
echo "ACCOUNT: $ACCOUNT"

[[ ! -z "${VERSION}" ]] \
    || { echo "Set VERSION (ex: v1.9.0)" && exit 1; }

[[ ! -z "${COMPANY_NAME}" ]] \
    || { echo "Set COMPANY_NAME (ex: mycompanyname )" && exit 1; }


[[ ! -z "${BUCKET}" ]] \
    || { echo "Set BUCKET (ex: mybucketname )" && exit 1; }

[[ ! -z "${REGION}" ]] \
    || { echo "Set REGION (ex: my aws region )" && exit 1; }

[[ ! -z "${PRIMARY_CLUSTER}" ]] \
    || { echo "Set PRIMARY_CLUSTER (ex: myclustersname )" && exit 1; }

[[ ! -z "${ACCOUNT}" ]] \
    || { echo "Set ACCOUNT (ex: set ACCOUNT by running ACCOUNT=$(aws sts get-caller-identity --query Account --output text)  )" && exit 1; }



echo "installing velero on the client"


(. ../01-install_velero_client.sh || { echo "velero failed to install on client" && exit 1 ; })

echo "making s3 bucket"

. ./02-make_s3_bucket.sh || { echo "velero failed to make an s3 bucket" && exit 1 ; }

echo "making IAM policies for velero"
. ./03-make_iam_policy.sh || { echo "failed to make IAM policies " && exit 1 ; }

echo "creating cluster service accts"
. ./04-create_velero_cluster_service_acct.sh || { echo "failed to make cluster service accts " && exit 1 ; }

echo "installing velero helm repo"
. ./05-velero_helm_repo_install.sh || { echo "failed to install velero helm chart repo " && exit 1 ; }

echo "creating velero helm chart overrides"
. ./06-velero_helm_setup.sh || { echo "failed to create velero helm chart overrides" && exit 1 ; }

echo "installing velero on the cluster"
. ./07-velero_helm_cluster_install.sh || { echo "failed to create velero helm chart overrides" && exit 1 ; }


echo "velero is installed on the cluster and is ready to use" && exit 0;