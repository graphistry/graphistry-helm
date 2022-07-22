#!/bin/bash
if [[ $PRIMARY_CLUSTER ]]
then
( echo "installing velero on primary cluster" && cd ../../ && \
helm upgrade -i velero vmware-tanzu/velero \
    --create-namespace \
    --namespace velero \
    -f ./charts/graphistry-helm/velero_values_primary_cluster.yaml )
else
:
fi

if [[ $RECOVERY_CLUSTER ]]
then
(echo "installing velero on recovery cluster" && cd ../../ && \
helm upgrade -i velero vmware-tanzu/velero \
    --create-namespace \
    --namespace velero \
    -f ./charts/graphistry-helm/velero_values_recovery_cluster.yaml)
else
:
fi

