variable "cluster_name" {
  description = "the cluster name"
  type    = string
  default = "eks-dev-terraform"
}

variable "key_pair_name" {}

variable "availability_zone_name" {
  description = "the availability zone names"
  type    = string
  default = "us-east-1"
}

variable "disk_size" {
  description = "size of disk"
  type    = number
  default = 200
}

variable "instance_types" {
  description = "the instance types"
  type    = list
  default = ["g4dn.xlarge"]
}
variable "ami_type" {
  description = "the ami type - choose one with nvidia driver"
  type    = string
  default = "AL2_x86_64_GPU"
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

variable "ngc-api-key" {
  type = string
  description = "value of NGC api key"
}

variable "enable-ingress-nginx" {
  description = "If set to true, it will create a ingress-nginx namespace and install ingres-nginx controller"
  type = bool
  default = false
}

variable "enable-grafana" {
  description = "If set to true, it will create a prometheus namespace and install prometheus and grafana"
  type = bool
  default = false
}

variable "enable-morpheus" {
  description = "If set to true, it will create a morpheus namespace and install morpheus & mlflow"
  type = bool
  default = false
}

variable "enable-ssh" {
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
#    {
#      name    = "aws-ebs-csi-driver"
#      version = "v1.10.0-eksbuild.1"
#    }
  ]
}

variable "docker-password" {
  description = "docker password"
  type    = string

}
variable "docker-username" {
  description = "docker username"
  type    = string
}
variable "docker-server" {
  description = "the docker server"
  type    = string
  default = "docker.io"
}


