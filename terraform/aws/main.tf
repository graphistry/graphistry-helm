## Graphistry Terraform AWS utilizing karpenter for autoscaling nodes and argoCD for helm chart management
## must run bundler.sh first from root dir - $bash chart-bundler/bundler.sh 
##
##
##this aws terraform utilizes karpenter.sh to create a kubernetes cluster with autoscaling

terraform {
  required_version = "~> 1.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.5.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.14.0"
    }
  }
}

provider "aws" {

  region = var.availability_zone_name
}

locals {
  cluster_name = var.cluster_name

  # Used to determine correct partition (i.e. - `aws`, `aws-gov`, `aws-cn`, etc.)
  partition = data.aws_partition.current.partition
}

data "aws_partition" "current" {}

resource "aws_eks_addon" "addons" {
  depends_on = [
   aws_iam_instance_profile.karpenter 
  ]
  for_each                 = { for addon in var.addons : addon.name => addon }
  cluster_name             = module.eks.cluster_id
  addon_name               = each.value.name
  addon_version            = each.value.version
  resolve_conflicts = "OVERWRITE"
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${local.cluster_name}"
  role = module.eks.eks_managed_node_groups["nodegroup_3"].iam_role_name
}

module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "4.17.1"

  role_name                          = "karpenter-controller-${local.cluster_name}"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_id = module.eks.cluster_id
  karpenter_controller_node_iam_role_arns = [
    module.eks.eks_managed_node_groups["nodegroup_3"].iam_role_arn
  ]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}


module "vpc" {
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.12.0"

  name = local.cluster_name
  cidr = var.cidr

  azs             = var.availability_zone_subnet
  private_subnets = var.private_subnet 
  public_subnets  = var.public_subnet 


  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
    }
  }
}
resource "helm_release" "k8s-device-plugin" {
  name  = "k8s-device-plugin"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart = "nvidia-device-plugin"
  version = "0.12.3"
  namespace = "nvidia-device-plugin"
  create_namespace = true
}

resource "helm_release" "gpu-prometheus" {
  count      = var.enable-grafana ? 1 : 0
  name       = "gpu-exporter"
  repository = "https://nvidia.github.io/dcgm-exporter/helm-charts"
  chart      = "dcgm-exporter"
  namespace  = "kube-system"
}


resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "v0.10.0"

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }

  set {
    name  = "clusterName"
    value = module.eks.cluster_id
  }

  set {
    name  = "clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter.name
  }
}
resource "null_resource" "patch_aws_cni" {
  depends_on = [
     module.eks.node_group_id,
     helm_release.argo
  ]

  provisioner "local-exec" {
    command = <<EOF
# do all those commands to get kubectl and auth info, then run:
aws eks update-kubeconfig --region ${var.availability_zone_name} --name ${var.cluster_name}
kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true WARM_PREFIX_TARGET=2
EOF
  }
}

resource "helm_release" "ingress-nginx" {
  count      = var.enable-ingress-nginx && !var.enable-grafana ? 1 : 0

  name       = "ingress-nginx"
  chart      = "../../chart-bundle/ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true

#  values = [
#    "${file("../../charts/ingress-nginx/values.yaml")}"
#  ]
}

resource "helm_release" "ingress-nginx-grafana" {
  count      =  var.enable-ingress-nginx  && var.enable-grafana ? 1 : 0
  name       = "ingress-nginx"
  chart      = "../../chart-bundle/ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true

  values = [
    "${file("../../charts/values-overrides/auxiliary/ingress-nginx-values.yaml")}"
  ]
}
resource "aws_security_group" "remote_access" {
  name_prefix = "${local.cluster_name}-remote-access"
  description = "Allow remote SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
        # This will tag the launch template created for use by Karpenter
        "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name
      }
}

resource "helm_release" "grafana-stack" {
  depends_on = [
        kubectl_manifest.argo_apps
    ]
  count      = var.enable-grafana ? 1 : 0
  name       = "prometheus"
  chart      = "../../chart-bundle/kube-prom-stack"
  namespace  = "prometheus"
  create_namespace = true

  values = [
    "${file("../../charts/values-overrides/auxiliary/kube-prom-values.yaml")}"
  ]
}

resource "helm_release" "morpheus-ai-engine" {
  depends_on = [
        kubectl_manifest.argo_apps
    ]
  count      = var.enable-morpheus ? 1 : 0 
  name       = "morpheus"
  chart      = "../../chart-bundle/Morpheus-ai-engine"
  namespace  = "morpheus"
  create_namespace = true

  set {
    name  = "ngc.apiKey"
    value = var.ngc-api-key
  }

  set {
    name  = "aiengine.args"
    value = "{tritonserver,--model-repository=/common/models,--model-control-mode=explicit}"
  }
}

resource "helm_release" "morpheus-mlflow" {
  depends_on = [
        kubectl_manifest.argo_apps,
        helm_release.morpheus-ai-engine
    ]
  count      = var.enable-morpheus ? 1 : 0
  name       = "morpheus-mlflow"
  chart      = "../../chart-bundle/NVIDIA-morpheus-mlflow-plugin"
  namespace  = "morpheus"
  create_namespace = true

  set {
    name  = "ngc.apiKey"
    value = var.ngc-api-key
  }
}

resource "helm_release" "cert-manager" {
  depends_on = [
        kubectl_manifest.argo_apps
    ]

  count      = var.enable-cert-manager ? 1 : 0
  name       = "cert-manager"
  chart      = "../../chart-bundle/cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  values = [
    "${file("../../charts/values-overrides/auxiliary/cert-manager-values.yaml")}"
  ]
}

resource "helm_release" "argo" {
  name       = "argo-cd"
  chart      = "../../chart-bundle/argo-cd"
  namespace  = "argo-cd"
  create_namespace = true

  values = [
    "${file("../../chart-bundle/argo-cd/argo-values.yaml")}"
  ]
}


data "template_file" "docker_config_script" {
  template = "${file("${path.module}/config.json")}"
  vars = {
    docker-username           = "${var.docker-username}"
    docker-password           = "${var.docker-password}"
    docker-server             = "${var.docker-server}"
    auth                      = base64encode("${var.docker-username}:${var.docker-password}")
  }
}

resource "kubernetes_namespace" "create_graphistry_namespace" {
  metadata {
    name = "graphistry"
  }
}

resource "kubernetes_secret" "docker-registry" {
  depends_on = [
        kubernetes_namespace.create_graphistry_namespace
    ]
  metadata {
    name = "docker-secret-prod"
    namespace = "graphistry"
  }

  data = {
    ".dockerconfigjson" = "${data.template_file.docker_config_script.rendered}"
  }

  type = "kubernetes.io/dockerconfigjson"
}


data "helm_template" "argo_instance" {
  name       = "argo-cd"
  chart      = "../../cd/argo-apps/"
}


output "argo_instance_manifests" {
  value = data.helm_template.argo_instance.manifests
}

resource "kubectl_manifest" "argo_apps" {
  for_each = "${data.helm_template.argo_instance.manifests}" 
  yaml_body = each.value
  depends_on = [
        helm_release.argo,
        kubernetes_secret.docker-registry

    ]
}

resource "kubectl_manifest" "karpenter_provisioner" {
  yaml_body = <<-YAML
  apiVersion: karpenter.sh/v1alpha5
  kind: Provisioner
  metadata:
    name: default
  spec:
    requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["spot"]
    limits:
      resources:
        cpu: 1000
    provider:
      subnetSelector:
        karpenter.sh/discovery: ${local.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${local.cluster_name}
      tags:
        karpenter.sh/discovery: ${local.cluster_name}
    ttlSecondsAfterEmpty: 30
  YAML

  depends_on = [
    helm_release.karpenter
  ]
} 



module "eks" {
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  source  = "terraform-aws-modules/eks/aws"
  version = "18.21.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version
  
  cluster_endpoint_private_access = var.enable-ssh == true ? true : null
  cluster_endpoint_public_access  = var.enable-ssh == true ? true : null

  cluster_endpoint_public_access_cidrs = ["${var.cluster_endpoint_public_access_cidrs}"]


  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets



  # Required for Karpenter role below
  enable_irsa = true

  node_security_group_additional_rules = {
    ingress_nodes_karpenter_port = {
      description                   = "Cluster API to Node group for Karpenter webhook"
      protocol                      = "tcp"
      from_port                     = 8443
      to_port                       = 8443
      type                          = "ingress"
      source_cluster_security_group = true
    }

    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      source_cluster_security_group = true
    }
  }

  node_security_group_tags = {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name
  }


  # Only need one node to get Karpenter up and running.
  # This ensures core services such as VPC CNI, CoreDNS, etc. are up and running
  # so that Karpenter can be deployed and start managing compute capacity as required
  eks_managed_node_groups = {
    nodegroup_3 = {
        # See issue https://github.com/awslabs/amazon-eks-ami/issues/844
      pre_bootstrap_user_data = <<-EOT
      #!/bin/bash
      set -ex
      cat <<-EOF > /etc/profile.d/bootstrap.sh
      export USE_MAX_PODS=false
      export KUBELET_EXTRA_ARGS="--max-pods=110"
      EOF
      if ! grep -q imageGCHighThresholdPercent /etc/kubernetes/kubelet/kubelet-config.json; 
      then 
          sed -i '/"apiVersion*/a \ \ "imageGCHighThresholdPercent": 70,' /etc/kubernetes/kubelet/kubelet-config.json
      fi

      # Inject imageGCLowThresholdPercent value unless it has already been set.
      if ! grep -q imageGCLowThresholdPercent /etc/kubernetes/kubelet/kubelet-config.json; 
      then 
          sed -i '/"imageGCHigh*/a \ \ "imageGCLowThresholdPercent": 50,' /etc/kubernetes/kubelet/kubelet-config.json
      fi
      # Source extra environment variables in bootstrap script
      sed -i '/^set -o errexit/a\\nsource /etc/profile.d/bootstrap.sh' /etc/eks/bootstrap.sh
      sed -i 's/KUBELET_EXTRA_ARGS=$2/KUBELET_EXTRA_ARGS="$2 $KUBELET_EXTRA_ARGS"/' /etc/eks/bootstrap.sh
      EOT

      ami_type = var.ami_type
      instance_types = var.instance_types
      # Not required nor used - avoid tagging two security groups with same tag as well
      create_security_group = false


      # Ensure enough capacity to run 2 Karpenter pods
      min_size     = var.cluster_size["min_size"]
      max_size     = var.cluster_size["max_size"]
      desired_size = var.cluster_size["desired_size"]
      disk_size    = var.disk_size
      remote_access = {
        ec2_ssh_key               = var.key_pair_name
        source_security_group_ids = [aws_security_group.remote_access.id]
      }
      create_launch_template = false
      launch_template_name   = "" 

      iam_role_additional_policies = [
        # Required by Karpenter
        "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",   
        "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"     
      ]
      labels = {
        accelerator: "nvidia"
      }

      tags = {
        # This will tag the launch template created for use by Karpenter
        "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name
      }
    }


  }
}

#if enable-morpheus is set to true apply terraform as below
#terraform apply -var=ngc-api-key="<api key here>" -var=docker-username="<your docker username>" -var=docker-password="<your docker password>"
#when node comes up run : (fixed with null_resource) can check via:
#kubectl describe ds aws-node -n kube-system
#kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true WARM_PREFIX_TARGET=1

##delete terraform state file for some reason or other..
#terraform state rm $(terraform state list | grep aws_instance)
#terraform state list | cut -f 1 -d '[' | xargs -L 0 terraform state rm

#to set statefile to a bucket, edit the state_file_bucket.conf file and run the following command:
#terraform init -backend-config=state_file_bucket.conf
