cluster_name = "demo-tf-cluster"
availability_zone_name = "us-east-1"
cluster_size = {"min_size": 1, "max_size": 3, "desired_size": 1}
addons = [
    #{"name":"kube-proxy", "version":"v1.21.2-eksbuild.2"},
    #{"name":"coredns", "version":"v1.8.4-eksbuild.1"},
   #{"name":"vpc-cni", "version":"v1.7.10-eksbuild.2"},
    {"name":"aws-ebs-csi-driver","version":"v1.10.0-eksbuild.1"}
        ]
enable-ingress-nginx = true
enable-cert-manager = true
key_pair_name = "cody-key"