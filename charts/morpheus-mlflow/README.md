## Overview

NVIDIA Morpheus is an open AI application framework that provides cybersecurity developers with a highly optimized AI pipeline and pre-trained AI capabilities that, for the first time, allow them to instantaneously inspect all IP traffic across their data center fabric. Bringing a new level of security to data centers, Morpheus provides dynamic protection, real-time telemetry, adaptive policies, and cyber defenses for detecting and remediating cybersecurity threats.

### Setup

The Morpheus MLflow container is packaged as a [Kubernetes](https://kubernetes.io/docs/home/) (aka k8s) deployment using a [Helm](https://helm.sh/docs/) chart. NVIDIA provides installation instructions for the [NVIDIA Cloud Native Core Stack](https://github.com/NVIDIA/cloud-native-core) which incorporates the setup of these platforms and tools.

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

### Install Morpheus MLflow

Install the chart as follows:

```
helm fetch https://helm.ngc.nvidia.com/nvidia/morpheus/charts/morpheus-mlflow-22.06.tgz --username='$oauthtoken' --password=$API_KEY --untar
helm install --set ngc.apiKey="$API_KEY" \
 --namespace $NAMESPACE \
 mlflow1 \
 morpheus-mlflow
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

The identity of the public catalog MLflow plugin image which could be overridden for other registry locations. The withEngine field makes the MLflow plugin deployment pending of the node where the AI Engine (Triton) pod is scheduled.

```
mlflow:
  registry: "nvcr.io/nvidia/morpheus"
  image: mlflow-triton-plugin
  version: 1.24.0
  withEngine: false
```

A NodePort is exposed for remote access to the MLflow server.

```
dashboardPort: 30500
```

A local host path which can be used by the charts for sharing models and datasets.

```
hostCommonPath: /opt/morpheus/common
```

IThe imagePullPolicy determines whether the container runtime should retrieve an image from a registry to create the pod. Use 'Always' for development.

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

When deploying to OpenShift we need to create a ServiceAccount for attaching permissions, such as the use of hostPath volumes.

```
platform:
  openshift: false
```

Deployment in CSP environments such as AWS EC2 require a Load Balancer ingress.

```
loadBalancer:
  enabled: false
```

### Install Morpheus reference models

Currently, the Morpheus reference models are included inside the SDK container image. Using the default `sdk.args` from the charts, we can put the Morpheus SDK pod into a sleep mode for copying the models to a local host path.

```
helm install --set ngc.apiKey="$API_KEY" \
               --namespace $NAMESPACE \
               helper \
               morpheus-sdk-client
```

Shell to the **sdk-cli-helper** and copy models to `/common`, which is mapped by default to `/opt/morpheus/common` on the host and where MLFlow will have access to model files.

```
kubectl -n $NAMESPACE exec sdk-cli-helper -- cp -RL /workspace/models /common
```

### Interacting with the plugin

Once the MLflow server pod is deployed, you can make use of the plugin by running a bash shell in the pod container like this:

```
kubectl exec -it deploy/mlflow -- /bin/bash
(mlflow) root@mlflow-6cdd744679-9lb82:/mlflow#
```

### Publish reference models to MLflow

The `publish_model_to_mlflow` script is used to publish `onnx` or `tensorrt` models to MLflow.

```
python publish_model_to_mlflow.py \
 	--model_name ref_model_1 \
 	--model_file /sid-bert-onnx/1/sid-bert.onnx \
 	--model_config /sid-bert-onnx/config.pbtxt \
 --flavor onnx 

python publish_model_to_mlflow.py \
 	--model_name ref_model_1 \
 	--model_file /sid-bert-onnx/1/sid-bert.onnx \
 	--model_config /sid-bert-onnx/config.pbtxt \
 --flavor tensorrt
```

### Deploy reference models to Triton

```
mlflow deployments create -t triton --flavor onnx --name ref_model_1 -m models:/ref_model_1/1 -C "version=1"

mlflow deployments create -t triton --flavor onnx --name ref_model_2 -m models:/ref_model_2/1 -C "version=1"
```

### Deployments

The following deployment functions are implemented within the plugin.
The plugin will deploy the associated `config.pbtxt` with the saved model version.

#### Create Deployment

To create a deployment use the following command:

```
mlflow deployments create -t triton --flavor onnx --name mini_bert_onnx -m models:/mini_bert_onnx/1 -C "version=1"
```

#### Delete Deployment

```
mlflow deployments delete -t triton --name mini_bert_onnx/1 
```

#### Update Deployment

```
mlflow deployments update -t triton --flavor onnx --name mini_bert_onnx/1 -m models:/mini_bert_onnx/1
```

#### List Deployments

```
mlflow deployments list -t triton
```

#### Get Deployment

```
mlflow deployments get -t triton --name mini_bert_onnx
```
