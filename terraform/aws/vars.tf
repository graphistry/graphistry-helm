variable "cluster_name" {
  description = "the cluster name"
  type    = string
  default = "karpenter-demo"
}

variable "availability_zone_name" {
  description = "the availability zone names"
  type    = string
  default = "us-east-1"
}

variable "instance_types" {
  description = "the instance types"
  type    = list
  default = ["g4dn.xlarge"]
}

variable "cluster_size" {
    description = "the cluster size"
    type  = map
  default = {
     "min_size"     = 1
     "max_size"     = 2
     "desired_size" = 1
    }
}

variable "enable-cert-manager" {
  description = "If set to true, it will create a cert-manager namespace and install cert-manager"
  type = bool
  default = false
}


variable "enable-ingress-nginx" {
  description = "If set to true, it will create a ingress-nginx namespace and install ingres-nginx controller"
  type = bool
  default = false
}

variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))

  default = [
#    {
#      name    = "kube-proxy"
#      version = "v1.21.2-eksbuild.2"
#    },
#    {
#      name    = "vpc-cni"
#      version = "v1.10.1-eksbuild.1"
#    },
#    {
#      name    = "coredns"
#      version = "v1.8.4-eksbuild.1"
#    },
    {
      name    = "aws-ebs-csi-driver"
      version = "v1.10.0-eksbuild.1"
    }
  ]
}

