
10 mins to k8s
======================

This guide will walk you through the steps to deploy a basic Graphistry on Kubernetes without extra features. (TLS, argo, K8s-dashboard, prometheus stack,longhorn)

Make Secrets
-------------
Contact a Graphistry Engineer to authorize to our dockerhub to pull the graphistry container images.

.. code-block:: shell-session            
              
    
    kubectl create secret docker-registry docker-secret-prod \
        --namespace graphistry \
        --docker-server=docker.io \
        --docker-username=<docker username> \
        --docker-password=<docker password/token>


Install Nvidia Device Plugin (if needed)
-----------------------------------------

.. code-block:: shell-session            
              
    kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml

check to ensure the plugin was installed

.. code-block:: shell-session            
              
    kubectl get nodes -ojson | jq .items[].status.capacity | grep nvidia.com/gpu

Install Nginx Ingress Controller
---------------------------------
  .. tabs::

    .. tab:: Local From Source
      .. code-block:: shell-session            
                
         git clone https://github.com/graphistry/graphistry-helm && cd graphistry-helm
         cd charts/ingress-nginx && helm dep build
         helm upgrade -i ingress-nginx ./charts/ingress-nginx --namespace ingress-nginx --create-namespace 


    .. tab:: From Ingress-Nginx Helm Repo
      .. code-block:: shell-session            
                
         helm upgrade -i ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace


    .. tab:: From Graphistry Helm Repo
      .. code-block:: shell-session            
                
         helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
         helm upgrade -i ingress-nginx graphistry-helm/ingress-nginx --namespace ingress-nginx --create-namespace  

Install Postgres Operator , CRDs, Postgres Cluster
---------------------------------------------------
  .. tabs::

    .. tab:: Local from Source
      .. code-block:: shell-session            
                
         git clone https://github.com/graphistry/graphistry-helm && cd graphistry-helm
         helm upgrade -i postgres-operator ./charts/postgres-operator --namespace postgres-operator --create-namespace 
         helm upgrade -i  postgres-cluster ./charts/postgres-cluster --namespace graphistry --create-namespace 

    .. tab:: From Graphistry Helm Repo
      .. code-block:: shell-session            
                
         helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
         helm upgrade -i postgres-operator graphistry-helm/pgo --namespace postgres-operator --create-namespace 
         helm upgrade -i postgrescluster graphistry-helm/postgres-cluster --namespace graphistry --create-namespace  


Configuring Postgres Cluster
----------------------------

After Cluster is deployed, find the pv that is created and add the following label to it. This will allow the cluster to bind the pv to the pod upon redeployment.
      
    .. code-block:: shell-session


       kubectl get pv -n graphistry && kubectl label pv <pv name> pgo-postgres-cluster=graphistry-postgres        

Change the postgres password if needed. The default password is randomly generated AlphaNumeric string.

    .. code-block:: shell-session
 

       kubectl patch secret -n postgres-operator postgres-pguser-graphistry -p '{"stringData":{"password":"<password>","verifier":""}}'

Install Dask Operator and CRDs
------------------------------
  .. tabs::

    .. tab:: Local from Source
      .. code-block:: shell-session            
                
         git clone https://github.com/graphistry/graphistry-helm && cd graphistry-helm
         cd charts/dask-kubernetes-operator && helm dep build
         helm upgrade -i dask-operator ./charts/dask-kubernetes-operator --namespace dask-operator --create-namespace 


    .. tab:: From Dask Helm Repo
      .. code-block:: shell-session            
                
         helm upgrade -i dask-operator dask-kubernetes-operator --repo https://https://helm.dask.org/ --namespace dask-operator --create-namespace


    .. tab:: From Graphistry Helm Repo
      .. code-block:: shell-session            
                
         helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
         helm upgrade -i dask-operator graphistry-helm/dask-kubernetes-operator --namespace dask-operator --create-namespace  



Install Graphistry
-------------------


  .. tabs::

    .. tab:: Local from source
      .. code-block:: shell-session            
                
         git clone https://github.com/graphistry/graphistry-helm && cd graphistry-helm
         helm upgrade -i  graphistry-resources ./charts/graphistry-helm-resources --namespace graphistry --create-namespace 
         helm upgrade -i  g-chart ./charts/graphistry-helm --namespace graphistry --create-namespace 

    .. tab:: From Graphistry Helm Repo
      .. code-block:: shell-session            
                
         helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
         helm upgrade -i graphistry-resources graphistry-helm/graphistry-resources --namespace graphistry --create-namespace         
         helm upgrade -i g-chart graphistry-helm/Graphistry-Helm-Chart --namespace graphistry --create-namespace 

**NOTE:** graphistry resources must be installed first as this contains the storageclasses that the PVCs rely on in the graphistry-helm deployment.

Create a Secret for Graph App Kit (OPTIONAL)
---------------------------------------------
If you have a Graph App Kit enabled, you can create a secret to use it.


.. code-block:: yaml            
    :caption: gak-secret.yaml        

    apiVersion: v1
    kind: Secret
    metadata:  
      name: gak-secret
      namespace: graphistry
    type: Opaque
    stringData:
      username: <username here>
      password: <password here>
      
Create the secret above as gak-secret.yaml and run the following command to create the secret:

.. code-block:: shell-session            
    
    kubectl apply -f gak-secret.yaml  

Once you have Created the user provided in the secret in Graphistry, Graph App Kit will display dashboards.

Configuring Graphistry
----------------------

It is recommended to create a values.yaml override file to configure the chart. The default values.yaml file can be found in the chart directory. Examples can be found in the ./charts/values-overrides directory.
There are some Deployment specifc values which will need to be set, such as the **global.provisioner**, and **graphistryResources.storageClassParameters**, **global.nodeSelector**, and the **global.Tag** depending on your release. An example values.yaml can be 
seen below. This is an example based on an AWS EKS deployment's values.yaml

    .. code-block:: yaml

        volumeName:
            dataMount: pvc-91a0b93-f7c9-471c-b00b-ab6dfb59885f
            localMediaMount: pvc-89ac98bf-2d96-4690-9a24-fb19a93d2c43
            gakPublic: pvc-97h36989-9cfa-4058-b420-fbcab0c3dc7f
            gakPrivate: pvc-9ase0164-e483-4b54-62a5-79a7181071e5


        graphistryResources:
            storageClassParameters:
                csi.storage.k8s.io/fstype: ext4
                type: gp2

            
        global:
            provisioner: ebs.csi.aws.com
            tag: v2.39.28-admin
            nodeSelector: {"kubernetes.io/hostname": "ip-171-00-00-0.us-east-2.compute.internal"}
            imagePullPolicy: Always
            imagePullSecrets: 
              - name: docker-secret-prod

Once a values.yaml has been created it can be deployed with the following command:

    .. code-block:: shell-session

        helm upgrade -i g-chart ./charts/graphistry-helm --namespace graphistry --create-namespace --values ./values.yaml

Once the deployment is complete, the Graphistry UI can be accessed from the caddy ingress endpoint. The ingress endpoint can be found by running the following command:

    .. code-block:: shell-session

        kubectl get ingress -n graphistry


Volume Binding
--------------
After initial deployment , the PVCs (**gak-private,gak-public,data-mount,local-media-mount**) for graphistry will have PVs
dynamically provisioned for them by the storageclasses that graphistry-resources deploy, and the pods will bind to them
automatically. If the cluster is redeployed, the PVs will be released and the pods will not be able to bind to them. To fix this, 
the PVCs must include the volumename from the PV that was provisioned for it. 
Find the volume name by running the following command:

    .. code-block:: shell-session

        kubectl get pv -n graphistry

This will return a list of PVs that were provisioned for the PVCs. The volumename can be found in the output of the command 
corresponding to the PVC. Add the name to your values.yaml file under the volumeName section. An example values.yaml can be:

    .. code-block:: yaml

        volumeName:
            dataMount: pvc-91a0b93-f7c9-471c-b00b-ab6dfb59885f
            localMediaMount: pvc-89ac98bf-2d96-4690-9a24-fb19a93d2c43
            gakPublic: pvc-97h36989-9cfa-4058-b420-fbcab0c3dc7f
            gakPrivate: pvc-9ase0164-e483-4b54-62a5-79a7181071e5

Once you have updated your values.yaml file the deployment can be redeployed/upgraded and the Pods will bind to the PVs automatically.

    .. code-block:: shell-session

        helm upgrade -i g-chart ./charts/graphistry-helm --namespace graphistry --create-namespace --values ./<your-values.yaml>