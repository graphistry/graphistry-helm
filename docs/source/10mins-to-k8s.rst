
10 Minutes to Graphistry on Kubernetes
======================================

This guide walks you through the steps to deploy Graphistry on Kubernetes. For platform-specific instructions, see the deployment guides for `k3s <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/k3s>`_, `GKE <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke>`_, `Tanzu <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/tanzu>`_, or `Cluster (multinode) <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/cluster>`_.

Prerequisites
-------------

- A running Kubernetes cluster with GPU nodes
- ``kubectl`` configured to access the cluster
- Helm 3.x installed

Get Graphistry Helm Charts
--------------------------

.. code-block:: shell-session

    git clone https://github.com/graphistry/graphistry-helm
    cd graphistry-helm

Run the chart bundler to fetch auxiliary chart dependencies:

.. code-block:: shell-session

    bash chart-bundler/bundler.sh


Install GPU Support
-------------------

GPU Operator (Recommended)
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: shell-session

    helm repo add nvidia https://helm.ngc.nvidia.com/nvidia && helm repo update

    helm install --wait --generate-name \
        -n gpu-operator --create-namespace nvidia/gpu-operator \
        --set driver.enabled=false \
        --timeout 60m

Set ``--set driver.enabled=true`` and ``--set driver.version="<VERSION>"`` if the NVIDIA driver is not already installed on the host.

Graphistry v2.50.1+ uses RAPIDS 26.02 and publishes images in two flavors: CUDA 12 and CUDA 13. The ``cuda.version`` chart value accepts ``"12"`` or ``"13"``. The GPU driver must be compatible with the chosen CUDA version:

=============== ====== ================ ========================== ===============================================
Build           RAPIDS CUDA Toolkit     Recommended Min Driver     Verified On
=============== ====== ================ ========================== ===============================================
cuda.version=12 26.02  12.9.1           R575+ (575.51.03+)         driver 575.57.08, driver 580.126.20
cuda.version=13 26.02  13.1.0           R590+ (590.44.01+)         driver 590.48.01
=============== ====== ================ ========================== ===============================================

Older drivers may work via NVIDIA's `forward compatibility <https://docs.nvidia.com/deploy/cuda-compatibility/>`_ layer but are not verified by Graphistry. See the `RAPIDS Platform Support <https://docs.rapids.ai/platform-support/>`_ matrix and `CUDA Toolkit Release Notes <https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/>`_ for full details.

The chart default is ``cuda.version: "12"``. To use CUDA 13 (requires driver R590+), add ``--set cuda.version="13"`` to your Graphistry helm install command.

Wait for the operator pods to be ready:

.. code-block:: shell-session

    kubectl get pods -n gpu-operator --watch

Device Plugin (Alternative)
^^^^^^^^^^^^^^^^^^^^^^^^^^^

If NVIDIA drivers are already installed on your nodes and you do not want to use the GPU Operator:

.. code-block:: shell-session

    kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/master/nvidia-device-plugin.yml

Verify GPU Access
^^^^^^^^^^^^^^^^^

.. code-block:: shell-session

    kubectl get nodes -ojson | jq '.items[].status.capacity' | grep nvidia.com/gpu


Install Kubernetes Operators
-----------------------------

Postgres Operator
^^^^^^^^^^^^^^^^^

.. code-block:: shell-session

    helm install pgo ./charts-aux-bundled/pgo \
        --namespace postgres-operator --create-namespace

    kubectl get pods --watch --namespace postgres-operator

Dask Operator
^^^^^^^^^^^^^

.. code-block:: shell-session

    cd charts-aux-bundled/dask-kubernetes-operator/ && helm dep build && cd ../..

    helm upgrade -i dask-operator ./charts-aux-bundled/dask-kubernetes-operator \
        --namespace dask-operator --create-namespace

    kubectl get pods --watch --namespace dask-operator


Configure StorageClass
----------------------

Graphistry requires a StorageClass with ``reclaimPolicy: Retain`` so data is preserved across redeployments. For full details, see :doc:`configure-storageclass`.

Option A: Create a New StorageClass
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Use this reference template. Replace the ``provisioner`` with your platform's CSI driver:

.. code-block:: yaml

    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: retain-sc
    provisioner: <your-csi-provisioner>
    reclaimPolicy: Retain
    volumeBindingMode: WaitForFirstConsumer
    allowVolumeExpansion: true

Apply it:

.. code-block:: shell-session

    kubectl apply -f retain-sc.yaml

Common provisioners: ``rancher.io/local-path`` (k3s), ``pd.csi.storage.gke.io`` (GKE), ``csi.vsphere.vmware.com`` (Tanzu/vSphere).

Option B: Use an Existing StorageClass
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you already have a StorageClass with ``reclaimPolicy: Retain``, set ``global.storageClassNameOverride`` in your values file:

.. code-block:: yaml

    global:
      storageClassNameOverride: "your-existing-sc-name"


Create Namespace and Secrets
----------------------------

.. code-block:: shell-session

    kubectl create namespace graphistry

Create a Docker Hub secret (your account must have access to Graphistry images). Contact `Graphistry Support <https://www.graphistry.com/support>`_ to get access.

.. code-block:: shell-session

    kubectl create secret docker-registry docker-secret-prod \
        --namespace graphistry \
        --docker-server=docker.io \
        --docker-username=<YOUR_DOCKERHUB_USER> \
        --docker-password=<YOUR_DOCKERHUB_TOKEN>

Create a GAK Secret (Optional)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

For `Graph App Kit <https://github.com/graphistry/graph-app-kit>`_ dashboards:

.. code-block:: shell-session

    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Secret
    metadata:
      name: gak-secret
      namespace: graphistry
    type: Opaque
    stringData:
      username: graphistry_user
      password: graphistry_password
    EOF


Install Postgres Cluster
------------------------

.. code-block:: shell-session

    helm upgrade -i postgres-cluster ./charts/postgres-cluster \
        --namespace graphistry --create-namespace

Wait for postgres pods to be running:

.. code-block:: shell-session

    kubectl get pods --watch -n graphistry


Deployment Tiers
----------------

Graphistry v2.50.1+ supports four deployment tiers, each building on the previous. Set ``global.tier`` in your values file to control which services are deployed:

.. code-block:: yaml

    global:
      tier: "full"   # platform | analytics | viz | full

Each tier includes all capabilities of the previous tiers:

=========== ============================================================================== ============
Tier        Description                                                                    GPU Required
=========== ============================================================================== ============
``platform``  ``postgres`` + ``nexus``. Auth provider, foundation for Louie or other          No
              integrations. Minimum tier, services in the same namespace connect internally
              via ``http://nexus:8000``. For external access use port-forward or Ingress.
``analytics`` ``platform`` + ``caddy``, ``nginx``, ``redis``, ``dask-scheduler``,              Yes
              ``dask-cuda-worker``, ``forge-etl-python``. Public API access, GPU compute,
              ETL processing and GFQL graph queries.
``viz``       ``analytics`` + ``streamgl-sessions``, ``streamgl-gpu``, ``streamgl-viz``.       Yes
              Interactive graph visualization with WebGL rendering and real-time GPU layout.
``full``      ``viz`` + ``pivot``, ``notebook``, ``graph-app-kit`` (public/private).           Yes
              Investigation tools (Pivot), Jupyter notebooks and Streamlit dashboards.
              **Default tier**.
=========== ============================================================================== ============

Services per tier
^^^^^^^^^^^^^^^^^

========================= ========== ========== ==== =====
Service                   platform   analytics  viz  full
========================= ========== ========== ==== =====
``postgres`` (pg-cluster) X          X          X    X
``nexus``                 X          X          X    X
``caddy``                            X          X    X
``nginx``                            X          X    X
``redis``                            X          X    X
``dask-scheduler``                   X          X    X
``dask-cuda-worker``                 X          X    X
``forge-etl-python``                 X          X    X
``streamgl-sessions``                           X    X
``streamgl-gpu``                                X    X
``streamgl-viz``                                X    X
``pivot``                                            X
``notebook``                                         X
``graph-app-kit-public``                             X
``graph-app-kit-private``                            X
========================= ========== ========== ==== =====

PVCs per tier
^^^^^^^^^^^^^

============================== ========== ========== ==== =====
PVC                            platform   analytics  viz  full
============================== ========== ========== ==== =====
``data-mount`` (64Gi)          X          X          X    X
``local-media-mount`` (4Gi)    X          X          X    X
``uploads-files`` (40Gi)                  X          X    X
``gak-public`` (4Gi)                                      X
``gak-private`` (4Gi)                                     X
============================== ========== ========== ==== =====

Tiers and telemetry
^^^^^^^^^^^^^^^^^^^

Telemetry is orthogonal to the deployment tier. It is controlled independently via ``global.ENABLE_OPEN_TELEMETRY`` (default: ``true``). When enabled, the telemetry stack (otel-collector, Grafana, Prometheus, Jaeger, DCGM exporter, node exporter) deploys alongside whichever tier is selected. Services that are deployed export traces and metrics automatically; services not included in the tier simply don't emit data.

Install Graphistry
------------------

Create a values file for your deployment. See :doc:`values-override` for configuration options and the platform-specific guides for examples.

.. code-block:: shell-session

    helm upgrade -i g-chart ./charts/graphistry-helm \
        --values ./your-values.yaml \
        --namespace graphistry --create-namespace

Wait for all pods to be running:

.. code-block:: shell-session

    kubectl get pods --watch -n graphistry


Access Graphistry
-----------------

Get the service address:

.. code-block:: shell-session

    kubectl get services -n graphistry | grep caddy

Get the ingress address:

.. code-block:: shell-session

    kubectl get ingress -n graphistry

When ``ENABLE_OPEN_TELEMETRY: true`` and ``telemetryStack.OTEL_CLOUD_MODE: false`` are set, the telemetry stack is deployed as part of the cluster:

========================= ============================
Service                   Path
========================= ============================
Graphistry                ``http://<ADDRESS>/``
Grafana                   ``http://<ADDRESS>/grafana``
Jaeger                    ``http://<ADDRESS>/jaeger``
Prometheus                ``http://<ADDRESS>/prometheus``
========================= ============================

Once you open Graphistry in the browser, create an account for the admin user.


Update Graphistry
-----------------

When updating, preserve existing volume bindings so that data persists across redeployments. First, generate the ``volumeName`` block for your values file:

.. code-block:: shell-session

    echo "volumeName:
      dataMount: $(kubectl get pvc data-mount -n graphistry -o jsonpath='{.spec.volumeName}')
      localMediaMount: $(kubectl get pvc local-media-mount -n graphistry -o jsonpath='{.spec.volumeName}')
      uploadsFiles: $(kubectl get pvc uploads-files -n graphistry -o jsonpath='{.spec.volumeName}')
      gakPublic: $(kubectl get pvc gak-public -n graphistry -o jsonpath='{.spec.volumeName}')
      gakPrivate: $(kubectl get pvc gak-private -n graphistry -o jsonpath='{.spec.volumeName}')"

Copy the output into your values file, then run the normal upgrade command:

.. code-block:: shell-session

    helm upgrade -i g-chart ./charts/graphistry-helm \
        --values ./your-values.yaml \
        --namespace graphistry --create-namespace


Troubleshooting
---------------

Check Pod Status
^^^^^^^^^^^^^^^^

.. code-block:: shell-session

    kubectl get pods -n graphistry
    kubectl describe pod <pod-name> -n graphistry

Check Logs
^^^^^^^^^^

.. code-block:: shell-session

    kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep nexus) -f
    kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep forge-etl-python) -f
    kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep nginx) -f

Check PVC Status
^^^^^^^^^^^^^^^^

.. code-block:: shell-session

    kubectl get pvc -n graphistry

GPU Issues
^^^^^^^^^^

.. code-block:: shell-session

    kubectl get pods -n gpu-operator
    kubectl describe node <node-name> | grep -A 5 "Capacity:"
