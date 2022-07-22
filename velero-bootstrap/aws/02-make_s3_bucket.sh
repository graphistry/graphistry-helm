#!/bin/bash

COMPANY_NAME=${COMPANY_NAME:-graphistry}
BUCKET=${BUCKET:-$COMPANY_NAME-eks-velero-backups}
REGION=${REGION:-us-east-2}
echo "aws s3 mb s3://$BUCKET --region $REGION"