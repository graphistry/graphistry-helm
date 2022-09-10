#!/bin/bash
#checks if aws creds are created and if not creates them
if [[  -d /root/.aws ]]
then 

cat > /root/.aws/config <<EOF
[default]
region = us-east-2

[profile admin]
role_arn=$AWS_ROLE_ARN
source_profile=$SOURCE_PROFILE 

EOF
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY

[$SOURCE_PROFILE]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY

EOF
echo "AWS creds created"

else  

echo "directory doesnt exist creating.."
mkdir /root/.aws
cat > /root/.aws/config <<EOF
[default]
region = us-east-2

[profile admin]
role_arn=$AWS_ROLE_ARN
source_profile=$SOURCE_PROFILE 

EOF
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY

[$SOURCE_PROFILE]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY

EOF
echo "AWS creds created"
fi

echo "CLUSTER_NAME:" $CLUSTER_NAME
if [[ $CLUSTER_NAME == "skinny" ]]
then

    echo "creating kubeconfig for skinny cluster "
    aws eks update-kubeconfig --name dev-cluster --region us-east-2 --role-arn $AWS_ROLE_ARN
    echo "kubeconfig created"

elif [[ $CLUSTER_NAME == "eks-dev" ]]
then

    echo "creating kubeconfig for eks-dev2 cluster "
    aws eks update-kubeconfig --name k8s-cluster-managed --region us-east-2 --role-arn $AWS_ROLE_ARN
    echo "kubeconfig created"

else
:
fi

exit 0