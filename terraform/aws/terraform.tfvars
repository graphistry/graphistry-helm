###the cluster name
cluster_name = "eks-dev-tf-cluster"
##k8s version
kubernetes_version="1.24"
##cluster availability zone
availability_zone_name = "us-east-1"
###cluster availability zone subnet
availability_zone_subnet = ["us-east-1b","us-east-1c"]
##cidr block
#cidr = "10.0.0.0/16"
## private subnet
#private_subnet = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
## public subnet
#public_subnet = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
#instance type
instance_types = ["g4dn.2xlarge"]
###change cluster size
cluster_size = {"min_size": 1, "max_size": 3, "desired_size": 1}
###enable various cluster addons
addons = [
    #{"name":"kube-proxy", "version":"v1.21.2-eksbuild.2"},
    #{"name":"coredns", "version":"v1.8.4-eksbuild.1"},
    #{"name":"vpc-cni", "version":"v3.9.0-eksbuild.2"},
    {"name":"aws-ebs-csi-driver","version":"v1.19.0-eksbuild.1"}
        ]
###enable various deployment addons ####
enable-ingress-nginx = true
enable-cert-manager = true
#enable-grafana = true
#enable-morpheus = true
####ssh access with key
#key_pair_name = "<your key here>"
enable-ssh = true

#if enable-morpheus is set to true apply terraform as below
#terraform apply -var=ngc_api_key="<api key here>"
#else set enable-morpheus to false and apply terraform as below
#terraform apply

###terraform destroy -target=module.vpc
### will fail to destory unless manually delete load balancer