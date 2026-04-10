
Configuring Values
==================

The ``values.yaml`` is a configuration file used to customize the Helm chart deployment. It supports hierarchical overrides: values at the top of the file are chart-specific, while values under ``global:`` are shared across all charts.

It is recommended to create a values override file rather than modifying the chart's default ``values.yaml`` directly. Platform-specific examples are available:

- `k3s example <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/k3s>`_
- `GKE example <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/gke>`_
- `Tanzu example <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/tanzu>`_
- `Cluster (multinode) example <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/cluster>`_

Example Values File
-------------------

Below is an example ``values.yaml`` for a single-node deployment:

.. code-block:: yaml

    tls: false
    fwdHeaders: true

    networkPolicy:
      strict: false

    ingress:
      management:
        annotations:
          kubernetes.io/ingress.class: nginx

    ingressNamespace: ingress-nginx

    k8sDashboard:
      enabled: true
      readonly: false
      createServiceAccount: false

    global:
      ingressClassName: nginx
      provisioner: <your-csi-provisioner>

      # Override the StorageClass name used by all PVCs.
      # When empty, defaults to "retain-sc" (single-node) or "retain-sc-cluster" (cluster mode).
      # Example: storageClassNameOverride: "vsphere-sc"
      storageClassNameOverride: ""

      nodeSelector:
        nvidia.com/gpu.present: "true"

      tag: v2.50.1
      imagePullPolicy: Always
      imagePullSecrets:
        - name: docker-secret-prod

      # Telemetry
      ENABLE_OPEN_TELEMETRY: true
      telemetryStack:
        OTEL_CLOUD_MODE: false
        openTelemetryCollector:
          OTEL_COLLECTOR_OTLP_HTTP_ENDPOINT: ""
          OTEL_COLLECTOR_OTLP_USERNAME: ""
          OTEL_COLLECTOR_OTLP_PASSWORD: ""
        grafana:
          GF_SERVER_ROOT_URL: "/grafana"
          GF_SERVER_SERVE_FROM_SUB_PATH: "true"
        dcgmExporter:
          DCGM_EXPORTER_CLOCK_EVENTS_COUNT_WINDOW_SIZE: 1000

Deploy with:

.. code-block:: shell-session

    helm upgrade -i g-chart ./charts/graphistry-helm \
        --namespace graphistry --create-namespace \
        --values ./your-values.yaml

Mandatory Values
----------------

The following values must be set for a working deployment:

* **global.imagePullSecrets** -- Docker registry credentials for pulling Graphistry images
* **global.provisioner** -- CSI storage provisioner for your platform (e.g., ``rancher.io/local-path``, ``pd.csi.storage.gke.io``)
* **global.nodeSelector** -- Label selector to schedule pods on GPU nodes
* **global.tag** -- Graphistry version tag (e.g., ``v2.50.1``)

Optional but Recommended
-------------------------

* **global.storageClassNameOverride** -- Use a pre-existing StorageClass instead of the default ``retain-sc``. See :doc:`configure-storageclass`.
* **global.ENABLE_OPEN_TELEMETRY** -- Enable the OpenTelemetry telemetry stack (Grafana, Prometheus, Jaeger). See `Telemetry Documentation <https://graphistry-admin-docs.readthedocs.io/en/latest/telemetry/kubernetes.html>`_.
* **global.telemetryStack.OTEL_CLOUD_MODE** -- Set to ``true`` to export telemetry to an external backend (e.g., Grafana Cloud) instead of deploying a local stack.

For the full list of configurable parameters, see :doc:`graphistry-helm-docs`.
