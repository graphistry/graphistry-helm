## Overview

NVIDIA Morpheus is an open AI application framework that provides cybersecurity developers with a highly optimized AI pipeline and pre-trained AI capabilities that, for the first time, allow them to instantaneously inspect all IP traffic across their data center fabric. Bringing a new level of security to data centers, Morpheus provides dynamic protection, real-time telemetry, adaptive policies, and cyber defenses for detecting and remediating cybersecurity threats.

**NOTE:** This chart deploys publicly available images that originate from Docker Hub, specifically Kafka and Zookeeper. NVIDIA makes no representation as to support or suitability for production purposes of these container images.

### Setup

The Morpheus AI Engine container is packaged as a [Kubernetes](https://kubernetes.io/docs/home/) (aka k8s) deployment using a [Helm](https://helm.sh/docs/) chart. NVIDIA provides installation instructions for the [NVIDIA Cloud Native Core Stack](https://github.com/NVIDIA/cloud-native-core) which incorporates the setup of these platforms and tools. Morpheus and its use of Triton Inference Server are initially designed to use the T4 (e.g., the G4 instance type in AWS EC2), V100 (P3), or A100 family of GPU (P4d).

#### NGC API Key

First, you will need to set up your NGC API Key to access all the Morpheus components, using the instructions from the [NGC Registry CLI User Guide](https://docs.nvidia.com/dgx/ngc-registry-cli-user-guide/index.html#topic_3).
Once you have created your API key, create an environment variable containing your API key for use by the commands used further in these instructions:

```
export API_KEY="<your key>"
```

After installing the Cloud Native Core Stack, install and configure the NGC Registry CLI using the instructions from the [NGC Registry CLI User Guide](https://docs.nvidia.com/dgx/ngc-registry-cli-user-guide/index.html#topic_3).

#### Create Namespace for Morpheus

Create a namespace and an environment variable for the namespace to organize the k8s cluster deployed via EGX Stack and logically separate Morpheus-related deployments from other projects using the following command:

```
kubectl create namespace <some name>
export NAMESPACE="<some name>"
```

### Install Morpheus AI Engine

The Morpheus AI Engine consists of the following components:
- NVIDIA Triton Inference Server [ai-engine] from NVIDIA for processing inference requests.
- Apache Kafka [broker] to consume and publish messages.
- Apache Zookeeper [zookeeper] to maintain coordination between the Kafka Brokers.

Install the chart as follows:

```
helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-ai-engine-22.06.tgz --username='$oauthtoken' --password=$API_KEY --untar
helm install --set ngc.apiKey="$API_KEY" \
 --set aiengine.args="{tritonserver,--model-repository=/common/models,--model-control-mode=explicit}" \
 --namespace $NAMESPACE \
 morpheus1 \
 morpheus-ai-engine
```

### Chart values explained

The number of pod replicas for each deployment. Currently "1" is a sensible value for a standalone development environment.

```
replicaCount: 1
```

Various fields required to access the container images from NGC. For the public catalog images, it should be sufficient to just specify the provided username and your API_KEY.

```
ngc:
  username: "$oauthtoken"
  apiKey: ""
  org: ""
  team: ""
```

The identity of the public catalog Triton image which could be overridden for other registry locations. The default arguments launch the Triton server with a volume for models and explicit model loading (REST API loading, not directory polling).

```
aiengine:
  registry: "nvcr.io/nvidia"
  image: tritonserver
  version: 22.06-py3
  # don't use command due to nvidia_entrypoint.sh!
  args:
    - tritonserver
    - --model-repository
    - /common/triton-model-repo
    - --model-control-mode
    - explicit
```

The Kafka public container image from Docker Hub. A NodePort is exposed so that a remote Kafka producer or consumer client can interact with the broker.

```
broker:
  registry: "docker.io"
  image: bitnami/kafka
  version: 2.7.0
  brokerPort: 30092
```

The Zookeeper public container image from Docker Hub, used for Kafka instance coordination.

```
zookeeper:
  registry: "docker.io"
  image: zookeeper
  version: 3.6.3
```

A local host path which can be used by the charts for sharing models and datasets.

```
hostCommonPath: /opt/morpheus/common
```

The imagePullPolicy determines whether the container runtime should retrieve an image from a registry to create the pod. Use 'Always' for development.

```
imagePullPolicy: IfNotPresent
```

Image pull secrets provide the properly formatted credentials for accessing the container images from NGC. It essentially encodes the provided API_KEY. Note that Fleet Command deployments create these secrets automatically based on the FC org, named literally 'imagepullsecret'.

```
imagePullSecrets: 
- name: nvidia-registrykey-secret
# - name: imagepullsecret
```

When deploying to OpenShift we need to create a ServiceAccount for attaching permissions, such as the use of hostPath volumes.

```
serviceAccount:
  create: false
  name: morpheus
```

General flag for OpenShift adjustments.

```
platform:
  openshift: false
```

Deployment in CSP environments such as AWS EC2 require a Load Balancer ingress.

```
loadBalancer:
  enabled: false
```

Use a nodeSelector with OpenShift for GPU affinity. The default is nil for the non GPU Operator/NFD use case. Also, refer to the SDK chart deployment.

```
nodeSelector: {}
```
