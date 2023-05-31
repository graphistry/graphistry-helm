## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.0)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (~> 4.0)

- <a name="requirement_helm"></a> [helm](#requirement\_helm) (~> 2.5.1)

- <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) (~> 1.14)

- <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) (~> 2.14.0)

## Providers

The following providers are used by this module:

- <a name="provider_aws"></a> [aws](#provider\_aws) (4.36.1)

- <a name="provider_helm"></a> [helm](#provider\_helm) (2.5.1)

- <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) (1.14.0)

- <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) (2.14.0)

- <a name="provider_null"></a> [null](#provider\_null) (3.1.1)

- <a name="provider_template"></a> [template](#provider\_template) (2.2.0)

## Modules

The following Modules are called:

### <a name="module_eks"></a> [eks](#module\_eks)

Source: terraform-aws-modules/eks/aws

Version: 18.21.0

### <a name="module_karpenter_irsa"></a> [karpenter\_irsa](#module\_karpenter\_irsa)

Source: terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks

Version: 4.17.1

### <a name="module_vpc"></a> [vpc](#module\_vpc)

Source: terraform-aws-modules/vpc/aws

Version: 3.12.0

## Resources

The following resources are used by this module:

- [aws_eks_addon.addons](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon) (resource)
- [aws_iam_instance_profile.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) (resource)
- [aws_security_group.remote_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) (resource)
- [helm_release.argo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.cert-manager](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.gpu-prometheus](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.grafana-stack](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.ingress-nginx](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.ingress-nginx-grafana](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.k8s-device-plugin](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.morpheus-ai-engine](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [helm_release.morpheus-mlflow](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) (resource)
- [kubectl_manifest.argo_apps](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) (resource)
- [kubectl_manifest.karpenter_provisioner](https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/manifest) (resource)
- [kubernetes_namespace.create_graphistry_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) (resource)
- [kubernetes_secret.docker-registry](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) (resource)
- [null_resource.patch_aws_cni](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) (resource)
- [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) (data source)
- [helm_template.argo_instance](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) (data source)
- [template_file.docker_config_script](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) (data source)

## Required Inputs

The following input variables are required:

### <a name="input_docker-password"></a> [docker-password](#input\_docker-password)

Description: docker password

Type: `string`

### <a name="input_docker-username"></a> [docker-username](#input\_docker-username)

Description: docker username

Type: `string`

### <a name="input_key_pair_name"></a> [key\_pair\_name](#input\_key\_pair\_name)

Description: n/a

Type: `any`

### <a name="input_ngc-api-key"></a> [ngc-api-key](#input\_ngc-api-key)

Description: value of NGC api key

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_addons"></a> [addons](#input\_addons)

Description: n/a

Type:

```hcl
list(object({
    name    = string
    version = string
  }))
```

Default: `[]`

### <a name="input_ami_type"></a> [ami\_type](#input\_ami\_type)

Description: the ami type - choose one with nvidia driver

Type: `string`

Default: `"AL2_x86_64_GPU"`

### <a name="input_availability_zone_name"></a> [availability\_zone\_name](#input\_availability\_zone\_name)

Description: the availability zone names

Type: `string`

Default: `"us-east-1"`

### <a name="input_availability_zone_subnet"></a> [availability\_zone\_subnet](#input\_availability\_zone\_subnet)

Description: the availability zone subnets

Type: `list`

Default:

```json
[
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]
```

### <a name="input_cidr"></a> [cidr](#input\_cidr)

Description: the cidr block

Type: `string`

Default: `"10.0.0.0/16"`

### <a name="input_cluster_endpoint_public_access_cidrs"></a> [cluster\_endpoint\_public\_access\_cidrs](#input\_cluster\_endpoint\_public\_access\_cidrs)

Description: cluster endpoint public access cidrs default set to 0.0.0.0/0

Type: `string`

Default: `"0.0.0.0/0"`

### <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name)

Description: the cluster name

Type: `string`

Default: `"eks-dev-terraform"`

### <a name="input_cluster_size"></a> [cluster\_size](#input\_cluster\_size)

Description: the cluster size

Type: `map`

Default:

```json
{
  "desired_size": 1,
  "max_size": 2,
  "min_size": 1
}
```

### <a name="input_disk_size"></a> [disk\_size](#input\_disk\_size)

Description: size of disk

Type: `number`

Default: `200`

### <a name="input_docker-server"></a> [docker-server](#input\_docker-server)

Description: the docker server

Type: `string`

Default: `"docker.io"`

### <a name="input_enable-cert-manager"></a> [enable-cert-manager](#input\_enable-cert-manager)

Description: If set to true, it will create a cert-manager namespace and install cert-manager

Type: `bool`

Default: `false`

### <a name="input_enable-grafana"></a> [enable-grafana](#input\_enable-grafana)

Description: If set to true, it will create a prometheus namespace and install prometheus and grafana

Type: `bool`

Default: `false`

### <a name="input_enable-ingress-nginx"></a> [enable-ingress-nginx](#input\_enable-ingress-nginx)

Description: If set to true, it will create a ingress-nginx namespace and install ingres-nginx controller

Type: `bool`

Default: `false`

### <a name="input_enable-morpheus"></a> [enable-morpheus](#input\_enable-morpheus)

Description: If set to true, it will create a morpheus namespace and install morpheus & mlflow

Type: `bool`

Default: `false`

### <a name="input_enable-ssh"></a> [enable-ssh](#input\_enable-ssh)

Description: If set to true, it will allow SSH access to the nodes

Type: `bool`

Default: `false`

### <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types)

Description: the instance types

Type: `list`

Default:

```json
[
  "g4dn.xlarge"
]
```

### <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version)

Description: kubernetes version

Type: `string`

Default: `"1.24"`

### <a name="input_private_subnet"></a> [private\_subnet](#input\_private\_subnet)

Description: value of private subnet

Type: `list`

Default:

```json
[
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]
```

### <a name="input_public_subnet"></a> [public\_subnet](#input\_public\_subnet)

Description: value of public subnet

Type: `list`

Default:

```json
[
  "10.0.101.0/24",
  "10.0.102.0/24",
  "10.0.103.0/24"
]
```

## Outputs

The following outputs are exported:

### <a name="output_argo_instance_manifests"></a> [argo\_instance\_manifests](#output\_argo\_instance\_manifests)

Description: n/a
