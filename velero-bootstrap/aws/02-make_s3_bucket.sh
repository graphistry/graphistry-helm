#!/bin/bash

#COMPANY_NAME=${COMPANY_NAME:-graphistry}
#BUCKET=${BUCKET:-$COMPANY_NAME-eks-velero-backups}
#REGION=${REGION:-us-east-2}


aws s3api create-bucket \
    --bucket $BUCKET \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION