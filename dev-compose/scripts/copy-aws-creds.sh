#!/bin/bash
#checks if aws creds are created and if not creates them
if [[ ! -d /root/.aws ]]
then 
mkdir /root/.aws
cat > /root/.aws/config <<EOF
[default]
region = us-east-2
EOF
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF
echo "AWS creds created"
else  
echo "directory exists"
fi

if [[ $CLUSTER_ENV=='skinny' ]]
then


echo "creating kubeconfig for skinny cluster "
aws eks update-kubeconfig --region us-east-2 --name dev-cluster
$(aws eks update-kubeconfig --name dev-cluster --region us-east-2 --role-arn $AWS_ROLE_ARN) > /dev/null 2>&1 || { echo "Error creating kubeconfig" && exit 1; }


echo "kubeconfig created"
elif [[ $CLUSTER_ENV=='eks-dev2' ]]
then

echo "creating kubeconfig for eks-dev2 cluster "
aws eks update-kubeconfig --region us-east-2 --name k8s-cluster
$(aws eks update-kubeconfig --name k8s-cluster --region us-east-2 --role-arn $AWS_ROLE_ARN) > /dev/null 2>&1 || { echo "Error creating kubeconfig" && exit 1; }
echo "kubeconfig created"
else
:
fi

exit 0