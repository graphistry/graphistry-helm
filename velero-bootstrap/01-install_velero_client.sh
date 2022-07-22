#!/bin/bash

echo "installing velero on the client"
#VERSION=${VERSION:-v1.9.0}
wget https://github.com/vmware-tanzu/velero/releases/download/$VERSION/velero-$VERSION-linux-amd64.tar.gz
tar -xvf velero-$VERSION-linux-amd64.tar.gz -C /tmp
sudo mv /tmp/velero-$VERSION-linux-amd64/velero /usr/local/bin
echo "Velero version installed: $(velero version)"
rm velero-$VERSION-linux-amd64.tar.gz