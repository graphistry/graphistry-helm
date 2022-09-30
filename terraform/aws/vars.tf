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

variable "cluster_size" {
    type         = number
    min_size     = 1
    max_size     = 2
    desired_size = 1


}

variable "instance_types" {
  type    = list
  types = ["g4dn.xlarge"]
}