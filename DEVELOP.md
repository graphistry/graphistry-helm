# graphistry-helm developer docs

This document is for Graphistry helm contributors on tasks like setting up a local k8s, running Graphistry locally, submitting patches, and making new releases

For using the Graphistry helm charts in your own Kubernetes,  See the main [README](README.md)

For an even more encompassing list of commands and options, see the [kubectl cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

# TO-DOs

1) <s> calico rules </s>
2) env secrets 
3) autoscaling 
4) tls intercontainer termination 
5) some sort of observability down the line with Prometheus and grafana  with traefik when we begin to phase out nginx in favor of traefik 
6) k8s api dashboard
7) add logging
8) add multinode volume support with NFS (longhorn)

# Convenient Commands


## get pods
```kubectl get pods```


## describe a pod
```kubectl describe pod <name>```


## delete a helm chart
```helm delete <chart name>```


## install a helm chart
```helm install <chart name> ./<chart dir>```


## upgrade a chart
```helm upgrade <chart name> ./<chart dir>```


## get a bash shell on a pod
```kubectl exec -i -t <name> -- /bin/bash```


## get svc by name
```kubectl get service nginx```


## port forward a pod
```kubectl port-forward deployment/nginx 8000:80```


## get last 100 logs of a pod
```kubectl logs --tail=100 deployment/nginx```


## get logs of a pod and follow
```kubectl logs --follow deployment/nginx```



## add gpu daemonset to cluster
    
```kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml```

once daemonset has been installed and started
if successful will see nvidia.com/gpu in nodes capacity here \
```kubectl get nodes -ojson | jq .items[].status.capacity```



## upgrade with a test run to check that charts are working
```helm upgrade --dry-run graphchart-release  ./<chart dir>```


## lint helm charts
```helm lint  <chart dir>```


## print env in a pod
```kubectl exec envar-demo -- printenv```


## how to restart a pod 
```kubectl scale deployment nginx --replicas=0 && kubectl scale deployment nginx --replicas=1 ```


## cat a file in a pod
```kubectl exec -it deployments/nginx -- cat /etc/resolv.conf```


## convert conf to config map
```kubectl create configmap nginx-conf --from-file=./default.conf```


## describe configmap config in yaml 
```kubectl get configmaps nginx-conf -o yaml```


## describe prettified configmap config
```kubectl describe configmaps nginx-config | nl```


## kubectl get service -n kube-system
 ```checks cluster dns ip```
 


## get kube secrets
```kubectl get secrets```


## get namespace
```kubectl get namespace```

## parse env values
```yq e ".env[1]" ./charts/graphistry-helm/values.yaml```

## update yaml in place with yq
```yq e -i '.env[1] = "cool"' ./charts/graphistry-helm/values.yaml```

## check all api resources can interact with
```kubectl api-resources```

## get configmaps from specific namespace
```kubectl -n kube-public get configmaps```

## get pods on all namespaces
```kubectl get pods -A```

## get pods on a particular node
```kubectl describe node <node-name>```


## check storage of pod
```kubectl -n <namespace> exec <pod-name> df```


## delete pvcs 
```kubectl delete pvc --all```

## check storage on pod , includes pvc if mounted
```kubectl -n <namespace> exec <pod-name> -- df -h```

## continuously run kubectl get pods
```watch kubectl get pods```

## to get initcontainer logs
```kubectl logs deployments/nginx -c nginx-init-streamgl-viz```



## get contexts for kubectl 
```kubectl config get-contexts```


## change kubectl context
```kubectl config use-context <yourClusterName>```

## get nodes
```kubectl get nodes```

## describe the specified node
```kubectl describe node <node-name>```

## get yaml of particular pod
```kubectl get pod <pod_name> -o yaml```