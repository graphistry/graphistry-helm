
Telemetry
=========

Graphistry services export telemetry data (metrics and traces) using the `OpenTelemetry <https://opentelemetry.io/>`_ standard. In Kubernetes, telemetry is pushed to an OpenTelemetry Collector which forwards it to observability backends such as Prometheus, Jaeger, and Grafana.

The telemetry subchart lives at ``charts/graphistry-helm/charts/telemetry/`` and is deployed as part of the main Graphistry Helm release.


Deployment Modes
----------------

The telemetry stack supports three modes, controlled by two Helm values:

============================= ======================================= ===========================================================
Mode                          Values                                  What gets deployed
============================= ======================================= ===========================================================
**Local Stack** (default)     ``OTEL_CLOUD_MODE: false``              OTEL Collector + Prometheus + Grafana + Jaeger + Node Exporter + DCGM Exporter
**Cloud Mode**                ``OTEL_CLOUD_MODE: true``               OTEL Collector only (exports to external OTLP endpoint)
**Hybrid Mode**               Custom chart adjustments                Local tools + forwarding to external services
============================= ======================================= ===========================================================

Both modes require the master switch ``global.ENABLE_OPEN_TELEMETRY: true``.


Architecture
------------

Local Stack Mode
^^^^^^^^^^^^^^^^

.. code-block:: text

    Graphistry Services (gRPC :4317)
        |
        v
    OTEL Collector
        |--- [filters, batches, adds attributes] ----|
        |                                            |
        v                                            v
    Prometheus Exporter (:8889)              OTLP Exporter (:4317)
        |                                            |
        v                                            v
    Prometheus (:9090)                        Jaeger (:16686)
        |
        v
    Grafana (:3000)

    Node Exporter (:9100) --scraped by--> Prometheus
    DCGM Exporter (:9400) --scraped by--> Prometheus

All telemetry UIs are exposed through Ingress at subpaths:

========================= ============================
Service                   Path
========================= ============================
Grafana                   ``/grafana``
Prometheus                ``/prometheus``
Jaeger                    ``/jaeger``
========================= ============================

Cloud Mode
^^^^^^^^^^

Only the OTEL Collector is deployed. It exports metrics and traces to an external OTLP-compatible endpoint (e.g. Grafana Cloud) using HTTP with basic authentication, automatic retries, and a sending queue.

Cluster Mode
^^^^^^^^^^^^

In cluster deployments (``global.ENABLE_CLUSTER_MODE: true``), the telemetry architecture splits across leader and follower instances:

- **Leader** (``IS_FOLLOWER: false``): Deploys the full observability stack. The OTEL Collector receives telemetry from both local services and all follower collectors.
- **Follower** (``IS_FOLLOWER: true``): Deploys only the OTEL Collector (ClusterIP service). It receives telemetry from local services and forwards everything to the leader's collector via gRPC.

.. code-block:: text

    Follower Namespace                    Leader Namespace
    ==================                    ================
    Services -> OTEL Collector  ------>   OTEL Collector -> Prometheus
               (ClusterIP)       gRPC                    -> Jaeger
                                                         -> Grafana


Enabling Telemetry
------------------

Add the following to your values file:

.. code-block:: yaml

    global:
      ENABLE_OPEN_TELEMETRY: true

      telemetryStack:
        OTEL_CLOUD_MODE: false    # false = local stack, true = cloud

For cloud mode, also set the endpoint and credentials:

.. code-block:: yaml

    global:
      ENABLE_OPEN_TELEMETRY: true

      telemetryStack:
        OTEL_CLOUD_MODE: true
        openTelemetryCollector:
          OTEL_COLLECTOR_OTLP_HTTP_ENDPOINT: "https://otlp-gateway-prod-us-east-0.grafana.net/otlp"
          OTEL_COLLECTOR_OTLP_USERNAME: "<Grafana Cloud Instance ID>"
          OTEL_COLLECTOR_OTLP_PASSWORD: "<Grafana Cloud API Token>"


Configuration Reference
-----------------------

Master Switch
^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``global.ENABLE_OPEN_TELEMETRY``
     - ``false``
     - Enable the entire telemetry stack. When ``false``, no telemetry resources are deployed.

Mode Control
^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.OTEL_CLOUD_MODE``
     - ``false``
     - ``false``: deploy local stack (Prometheus, Grafana, Jaeger, DCGM Exporter, Node Exporter). ``true``: export to external OTLP endpoint.

OpenTelemetry Collector
^^^^^^^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.openTelemetryCollector.image``
     - ``otel/opentelemetry-collector-contrib:0.87.0``
     - Collector container image.
   * - ``telemetryStack.openTelemetryCollector.OTEL_COLLECTOR_OTLP_HTTP_ENDPOINT``
     - ``""``
     - Cloud mode only. OTLP HTTP endpoint (e.g. Grafana Cloud gateway).
   * - ``telemetryStack.openTelemetryCollector.OTEL_COLLECTOR_OTLP_USERNAME``
     - ``""``
     - Cloud mode only. Username or instance ID for OTLP authentication.
   * - ``telemetryStack.openTelemetryCollector.OTEL_COLLECTOR_OTLP_PASSWORD``
     - ``""``
     - Cloud mode only. API token or password for OTLP authentication.
   * - ``telemetryStack.openTelemetryCollector.LEADER_OTEL_EXPORTER_OTLP_ENDPOINT``
     - ``""``
     - Cluster mode only. Follower collectors export to this leader endpoint (e.g. ``otel-collector.graphistry.svc.cluster.local:4317``).

Grafana
^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.grafana.image``
     - ``grafana/grafana:11.0.0``
     - Grafana container image.
   * - ``telemetryStack.grafana.GF_SERVER_ROOT_URL``
     - ``/grafana``
     - Root URL path for Grafana behind reverse proxy.
   * - ``telemetryStack.grafana.GF_SERVER_SERVE_FROM_SUB_PATH``
     - ``true``
     - Serve Grafana from a sub-path.

Prometheus
^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.prometheus.image``
     - ``prom/prometheus:v2.47.2``
     - Prometheus container image.

Jaeger
^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.jaeger.image``
     - ``jaegertracing/all-in-one:1.50.0``
     - Jaeger all-in-one container image.
   * - ``telemetryStack.jaeger.OTEL_EXPORTER_JAEGER_ENDPOINT``
     - ``jaeger:4317``
     - gRPC endpoint the OTEL Collector exports traces to.

DCGM Exporter (GPU Metrics)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.dcgmExporter.image``
     - ``nvcr.io/nvidia/k8s/dcgm-exporter:4.2.3-4.1.1-ubuntu22.04``
     - NVIDIA DCGM Exporter container image.
   * - ``telemetryStack.dcgmExporter.DCGM_EXPORTER_CLOCK_EVENTS_COUNT_WINDOW_SIZE``
     - ``1000``
     - GPU metric sampling window in milliseconds. Smaller values give higher resolution but more overhead.

Node Exporter
^^^^^^^^^^^^^

.. list-table::
   :header-rows: 1
   :widths: 40 15 45

   * - Parameter
     - Default
     - Description
   * - ``telemetryStack.nodeExporter.image``
     - ``prom/node-exporter:v1.8.2``
     - Prometheus Node Exporter container image.


Components
----------

OpenTelemetry Collector
^^^^^^^^^^^^^^^^^^^^^^^

Deployed as a **DaemonSet** on every selected node. Receives telemetry from Graphistry services via gRPC OTLP on port ``4317``.

**Pipelines:**

- **Metrics pipeline**: ``otlp receiver`` -> ``memory_limiter`` -> ``batch`` -> ``attributes`` -> ``prometheus exporter`` (port 8889)
- **Traces pipeline**: ``otlp receiver`` -> ``memory_limiter`` -> ``filter/traces`` -> ``batch`` -> ``attributes`` -> ``otlp exporter`` (to Jaeger)

**Processors:**

- ``memory_limiter``: Prevents OOM (limit 450 MiB, spike 150 MiB, check every 5s).
- ``batch``: Batches telemetry for efficient transport (2000 items or 5s timeout).
- ``attributes/system-attribute``: Adds ``system=graphistry`` to all telemetry data.
- ``attributes/instance-attribute``: Adds ``graphistry_instance=<INSTANCE_NAME>`` to all telemetry data.
- ``filter/traces``: Drops noisy health-check and monitoring spans (``/health``, ``/check-workers``, ``/read``, ``/list?skipContextTest``, ``readHandler``) when status is 200.

**Resource limits**: CPU 500m-1000m, Memory 1-2Gi.

Prometheus
^^^^^^^^^^

Deployed as a **DaemonSet**. Scrapes metrics from:

.. list-table::
   :header-rows: 1
   :widths: 30 20 20

   * - Target
     - Port
     - Scrape Interval
   * - OTEL Collector
     - 8889
     - 5s
   * - DCGM Exporter
     - 9400
     - 1s
   * - Node Exporter
     - 9100
     - 1s

Serves the web UI at ``/prometheus`` via Ingress on port ``9090``.

**Resource limits**: CPU 500m-1000m, Memory 1-2Gi.

Grafana
^^^^^^^

Deployed as a **DaemonSet**. Reads from Prometheus as its default datasource (``http://prometheus:9090/prometheus``).

**Default credentials**: ``admin`` / ``admin``. Anonymous access is enabled with Admin role for convenience.

**Pre-provisioned dashboards:**

- **DCGM Exporter Dashboard** (GPU metrics): Temperature, power usage, SM clocks, GPU utilization, tensor core utilization, framebuffer memory. Includes ``instance`` and ``gpu`` template variables for filtering.
- **Node Exporter Full Dashboard** (host metrics): CPU, memory, disk, network.

Both dashboards are auto-provisioned from ConfigMaps. The Node Exporter dashboard is stored as a base64-encoded zip and extracted by an init container (to work within ConfigMap size limits).

Serves the web UI at ``/grafana`` via Ingress on port ``3000``.

**Resource limits**: CPU 250m-500m, Memory 500Mi-1Gi.

Jaeger
^^^^^^

Deployed as a **DaemonSet** using the ``all-in-one`` image (collector + query + agent). Receives traces from the OTEL Collector via gRPC on port ``4317``.

Serves the web UI at ``/jaeger`` via Ingress on port ``16686``. The UI has the monitor and dependencies menus enabled.

**Resource limits**: CPU 500m-1000m, Memory 1-2Gi.

DCGM Exporter
^^^^^^^^^^^^^^

Deployed as a **DaemonSet**. Exports NVIDIA GPU metrics in Prometheus format on port ``9400``. Requires ``SYS_ADMIN`` capability for GPU access.

**Metrics exported**: ``DCGM_FI_DEV_GPU_TEMP``, ``DCGM_FI_DEV_POWER_USAGE``, ``DCGM_FI_DEV_SM_CLOCK``, ``DCGM_FI_DEV_GPU_UTIL``, ``DCGM_FI_PROF_PIPE_TENSOR_ACTIVE``, ``DCGM_FI_DEV_FB_USED``.

**Resource limits**: CPU 200m-500m, Memory 200-500Mi.

.. note::

   On some platforms (GKE with COS nodes, Tanzu with vGPU), the GPU Operator's built-in DCGM exporter may conflict with this one. In those cases, you can use the GPU Operator's DCGM exporter as the scrape target instead. See the platform-specific READMEs for workaround details.

Node Exporter
^^^^^^^^^^^^^

Deployed as a **DaemonSet**. Exports host-level metrics (CPU, memory, disk, network) in Prometheus format on port ``9100``. Runs with ``--collector.processes`` flag.

**Resource limits**: CPU 100m-200m, Memory 100-200Mi.


Services and Ports
------------------

.. list-table::
   :header-rows: 1
   :widths: 20 10 15 35 20

   * - Service
     - Port
     - Protocol
     - Purpose
     - Type
   * - ``otel-collector``
     - 4317
     - gRPC
     - OTLP receiver (metrics + traces)
     - LoadBalancer / ClusterIP (follower)
   * - ``otel-collector``
     - 8889
     - HTTP
     - Prometheus metrics exporter
     - LoadBalancer / ClusterIP (follower)
   * - ``prometheus``
     - 9090
     - HTTP
     - Web UI and API
     - ClusterIP
   * - ``grafana``
     - 3000
     - HTTP
     - Web UI
     - ClusterIP
   * - ``jaeger``
     - 4317
     - gRPC
     - OTLP trace receiver
     - ClusterIP
   * - ``jaeger``
     - 16686
     - HTTP
     - Web UI
     - ClusterIP
   * - ``node-exporter``
     - 9100
     - HTTP
     - Prometheus metrics
     - ClusterIP
   * - ``dcgm-exporter``
     - 9400
     - HTTP
     - Prometheus GPU metrics
     - ClusterIP


Resource Requirements
---------------------

Total resource requirements when all local stack components are deployed:

.. list-table::
   :header-rows: 1
   :widths: 25 15 15 15 15

   * - Component
     - CPU Request
     - CPU Limit
     - Memory Request
     - Memory Limit
   * - OTEL Collector
     - 500m
     - 1000m
     - 1Gi
     - 2Gi
   * - Prometheus
     - 500m
     - 1000m
     - 1Gi
     - 2Gi
   * - Grafana
     - 250m
     - 500m
     - 500Mi
     - 1Gi
   * - Jaeger
     - 500m
     - 1000m
     - 1Gi
     - 2Gi
   * - Node Exporter
     - 100m
     - 200m
     - 100Mi
     - 200Mi
   * - DCGM Exporter
     - 200m
     - 500m
     - 200Mi
     - 500Mi
   * - **Total**
     - **2050m**
     - **4200m**
     - **3.8Gi**
     - **7.7Gi**


Cluster Mode Configuration
---------------------------

For multinode cluster deployments, telemetry is configured per instance:

**Leader values** (deploys full stack):

.. code-block:: yaml

    global:
      ENABLE_OPEN_TELEMETRY: true
      ENABLE_CLUSTER_MODE: true
      IS_FOLLOWER: false
      GRAPHISTRY_INSTANCE_NAME: "leader"

      telemetryStack:
        OTEL_CLOUD_MODE: false

**Follower values** (deploys collector only):

.. code-block:: yaml

    global:
      ENABLE_OPEN_TELEMETRY: true
      ENABLE_CLUSTER_MODE: true
      IS_FOLLOWER: true
      GRAPHISTRY_INSTANCE_NAME: "follower-1"

      telemetryStack:
        OTEL_CLOUD_MODE: false
        openTelemetryCollector:
          LEADER_OTEL_EXPORTER_OTLP_ENDPOINT: "otel-collector.graphistry.svc.cluster.local:4317"

Replace ``graphistry`` in the endpoint with the leader's namespace. See the `Cluster deployment guide <https://github.com/graphistry/graphistry-helm/tree/main/charts/values-overrides/examples/cluster>`_ for full configuration.


Caddy Reverse Proxy
--------------------

The telemetry Ingress rules route ``/grafana``, ``/prometheus``, and ``/jaeger`` to their respective services. The Caddy ConfigMap (``charts/graphistry-helm/templates/caddy/caddy-cfg.yml``) also handles reverse proxy routing for these paths internally.

To customize Caddy routing (e.g. adding authentication or custom headers):

1. Edit the Caddy ConfigMap template.
2. Delete the existing ConfigMap: ``kubectl delete configmap caddy-config -n graphistry``
3. Upgrade the Helm release to apply the new template.
4. Restart the Caddy pod: ``kubectl delete $(kubectl get pods -n graphistry -o name | grep caddy-graphistry) -n graphistry``
5. Verify: ``kubectl get configmap caddy-config -n graphistry -o yaml``


Troubleshooting
---------------

Verify telemetry pods are running:

.. code-block:: shell-session

    kubectl get pods -n graphistry | grep -E "otel|prometheus|grafana|jaeger|node-exporter|dcgm"

Check OTEL Collector logs:

.. code-block:: shell-session

    kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep otel-collector) -f

Verify Prometheus is scraping targets (open ``/prometheus/targets`` in browser or):

.. code-block:: shell-session

    kubectl port-forward -n graphistry svc/prometheus 9090:9090
    # Then open http://localhost:9090/prometheus/targets

Verify GPU metrics are being collected:

.. code-block:: shell-session

    kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep dcgm-exporter)

Check Grafana datasource connectivity:

.. code-block:: shell-session

    kubectl logs -n graphistry $(kubectl get pods -n graphistry -o name | grep grafana)
