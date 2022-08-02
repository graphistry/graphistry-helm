#!/bin/bash
#checks if aws creds are created and if not creates them
if [[ ! -d /root/.aws ]]; 
then 
cat > /root/.aws/config <<EOF
[default]
region = us-east-2
EOF
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF
else  
echo "directory exists"
fi