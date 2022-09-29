
Configuring the Override
========================

The values.yaml is a cluster-wide configuration file.  It is used to configure the default values for all the charts in the cluster.
The values.yaml file is a hierarchical file.  
The values at the top of the file are chart specific and will only be applied to the chart they are associated with.  
The values at the bottom of the file are are global and will be applied to all charts.
The Charts are organized as "sibling charts" so the values can be applied and overridden at the chart level with the values in a section named after the corresponding Helm Chart.

Here is an example of a values.yaml for all of the individual services taken from a AWS EKS deployment:

    .. code-block:: yaml

        ##values for graphistry-helm
        domain: your-site.com 
        tlsEmail: "admin@your-site.com" 
        tls: true
        metrics: true
        fwdHeaders: true
        volumeName:
            dataMount: pvc-91ac0b15-f7c9-471c-a00d-ab6dfb59885f
            localMediaMount: pvc-89de61bf-2d96-4613-9a24-fb19a93d2c43
            gakPublic: pvc-97b39989-9cfa-4058-b489-fbcab0c3dc7f
            gakPrivate: pvc-9afe0118-e483-4b90-85a5-79a7181071e5

        ##values for graphistry-resources
        graphistryResources:
            storageClassParameters:
                csi.storage.k8s.io/fstype: ext4
                type: gp2

        ##values for kubernetes dashboard

        k8sDashboard:
            enabled: true
            readonly: false
            createServiceAccount: false  ## createServiceAccount: true only on initial deployment

        ##values for grafana
        grafana:
            grafana.ini:
                server:
                    domain: your-site.com
                    root_url: https://your-site.com/k8s/grafana
                    serve_from_sub_path: true
                auth.anonymous:
                    enabled: true

        ##values for prometheus
        prometheus:
            prometheusSpec:
                serviceMonitorSelectorNilUsesHelmValues: false

        ##values for ingress-nginx ingress controller when prometheus is installed
        ingress-nginx:
            controller:
                metrics:
                enabled: true 
                serviceMonitor:
                    enabled: true 
                    additionalLabels:
                    release: "prometheus"

        ##values for cert-manager
        cert-manager: #defined by either the name or alias of your dependency in Chart.yaml
            namespace: cert-manager
            installCRDs: true
            createCustomResource: true
            
        ##values for global    
        global:
            provisioner: ebs.csi.aws.com
            tag: v2.39.28-admin
            nodeSelector: {"kubernetes.io/hostname": "ip-171-00-00-0.us-west-2.compute.internal"}
            logs:
              LogLevel: "TRACE"
                  GraphistryLogLevel: "TRACE"
            imagePullPolicy: Always
            imagePullSecrets: 
              - name: docker-secret-prod

Mandatory Values
----------------

Some of the global values are mandatory to work correctly.  These are:

* **global.imagePullSecrets**
* **global.provisioner**
* **global.nodeSelector**
* **graphistryResources.storageClassParameters**
* **global.tag**



For more information on configuration options for each chart, see the Configuration section in each corresponding chapter.




