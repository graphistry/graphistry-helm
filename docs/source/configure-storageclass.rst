
Configure StorageClass
======================

Graphistry uses Kubernetes `Persistent Volume Claims <https://kubernetes.io/docs/concepts/storage/persistent-volumes/>`_ (PVCs) to store data. Each PVC references a StorageClass, which defines how storage is dynamically provisioned.

Why Retain?
-----------

Graphistry requires a StorageClass with ``reclaimPolicy: Retain``. This ensures that when a Helm release is uninstalled or a PVC is deleted, the underlying Persistent Volume (PV) and its data are preserved. Without Retain, uninstalling and reinstalling Graphistry would destroy all stored data (postgres databases, uploaded files, notebooks, visualizations).

.. note::

   With ``reclaimPolicy: Retain``, PVs remain in ``Released`` state after PVC deletion and must be manually cleaned up by the cluster admin. This is the intended behavior -- data safety over convenience.


StorageClass Requirements
-------------------------

================================ ======================== =============================================
Property                         Value                    Description
================================ ======================== =============================================
``reclaimPolicy``                Retain                   Data preserved when PVC deleted
``volumeBindingMode``            WaitForFirstConsumer     PV created only when a pod needs it
``allowVolumeExpansion``         true                     Allows resizing volumes without recreating
================================ ======================== =============================================


Option A: Create a New StorageClass
-----------------------------------

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

Platform-specific provisioners:

======================== ====================================== =====
Platform                 Provisioner                            Notes
======================== ====================================== =====
k3s                      ``rancher.io/local-path``              Local storage on the node
GKE                      ``pd.csi.storage.gke.io``              Persistent Disk (add ``type: pd-balanced``)
Tanzu / vSphere          ``csi.vsphere.vmware.com``             Requires ``storagepolicyname`` parameter
EKS                      ``ebs.csi.aws.com``                    Elastic Block Store
AKS                      ``disk.csi.azure.com``                 Azure Managed Disk
======================== ====================================== =====

See the platform-specific deployment guides for complete manifests:
`k3s <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/k3s>`_,
`GKE <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke>`_,
`Tanzu <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/tanzu>`_.

Apply the StorageClass before deploying Graphistry:

.. code-block:: shell-session

    kubectl apply -f retain-sc.yaml


Option B: Use an Existing StorageClass
--------------------------------------

If you already have a StorageClass with ``reclaimPolicy: Retain``, you can point all Graphistry PVCs to it by setting ``global.storageClassNameOverride`` in your values file:

.. code-block:: yaml

    global:
      # Override the StorageClass name used by all PVCs (data-mount, local-media, gak-public,
      # gak-private, uploads-files, and postgres volumes). The StorageClass must be pre-created
      # by the cluster admin with reclaimPolicy: Retain to preserve data across redeployments.
      # When empty, defaults to "retain-sc" (single-node) or "retain-sc-cluster" (cluster mode).
      # Example: storageClassNameOverride: "vsphere-sc"
      storageClassNameOverride: "your-existing-sc-name"

Check your existing StorageClasses:

.. code-block:: shell-session

    kubectl get sc


PVCs and Services
-----------------

All PVCs reference the same StorageClass (default: ``retain-sc``).

============================== ==============================================================================================
PVC                            Used By Services
============================== ==============================================================================================
``data-mount``                 nexus, nginx, forge-etl-python, streamgl-gpu, streamgl-viz, streamgl-sessions,
                               dask-scheduler, dask-cuda-worker, redis, pivot, caddy, notebook
``local-media-mount``          nexus, nginx
``gak-public``                 graph-app-kit-public, notebook
``gak-private``                graph-app-kit-private, notebook
``uploads-files``              nginx, forge-etl-python
============================== ==============================================================================================


Postgres Storage
----------------

The ``postgres-cluster`` chart creates a ``PostgresCluster`` CR. The PGO operator dynamically provisions PVCs using the same StorageClass:

- Instance data volume (e.g., ``postgres-instance1-xxxx-0``)
- Backup repository volume for pgBackRest

Both volumes also respect ``global.storageClassNameOverride`` when set.


Volume Binding on Redeployment
------------------------------

After initial deployment, PVCs are dynamically provisioned and pods bind to them automatically. If the Helm release is uninstalled and reinstalled, the PVs (with ``Retain`` policy) will be in ``Released`` state and will not automatically rebind.

To preserve volume bindings across redeployments, generate the ``volumeName`` block for your values file:

.. code-block:: shell-session

    echo "volumeName:
      dataMount: $(kubectl get pvc data-mount -n graphistry -o jsonpath='{.spec.volumeName}')
      localMediaMount: $(kubectl get pvc local-media-mount -n graphistry -o jsonpath='{.spec.volumeName}')
      gakPublic: $(kubectl get pvc gak-public -n graphistry -o jsonpath='{.spec.volumeName}')
      gakPrivate: $(kubectl get pvc gak-private -n graphistry -o jsonpath='{.spec.volumeName}')"

Copy the output into your values file, for example:

.. code-block:: yaml

    volumeName:
      dataMount: pvc-91a0b93-f7c9-471c-b00b-ab6dfb59885f
      localMediaMount: pvc-89ac98bf-2d96-4690-9a24-fb19a93d2c43
      gakPublic: pvc-97h36989-9cfa-4058-b420-fbcab0c3dc7f
      gakPrivate: pvc-9ase0164-e483-4b54-62a5-79a7181071e5

Then run the normal upgrade command:

.. code-block:: shell-session

    helm upgrade -i g-chart ./charts/graphistry-helm \
        --values ./your-values.yaml \
        --namespace graphistry --create-namespace
