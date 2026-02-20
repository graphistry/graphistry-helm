
# graphistry-helm Version Release Notes

## Changelog

All notable changes to the graphistry-helm repo are documented in this file. Additional Graphistry components are tracked in the main [Graphistry major release history documentation](https://graphistry.zendesk.com/hc/en-us/articles/360033184174-Enterprise-Release-List-Downloads).

The changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and all PyGraphistry-specific breaking changes are explictly noted here.

## [Development]
*   Working on fixing the Top level persistence for jupyter Notebooks, currently it is persistent inside the different directories but top level resets on redeployment.

## [Version 0.4.1 - 2026-02-05]

### Removed

- `graphistry-helm-resources` chart: Deleted from the repository. StorageClasses are now the cluster admin's responsibility, following Kubernetes and Helm ecosystem best practices. Platform guides include example StorageClass manifests. This chart was a separate Helm release (never a subchart of `graphistry-helm`), so upgrading `g-chart` does not affect existing deployments. StorageClasses and PVCs already provisioned by the old chart remain in the cluster.
- ELK stack template (`templates/elk/elk.yaml`): Removed along with `elk.enabled` and `elk.version` from `values.yaml`. The ELK stack was disabled by default (`elk.enabled: false`). Users who had explicitly enabled it should migrate to the OpenTelemetry telemetry stack (Grafana, Prometheus, Jaeger) added in v0.3.8.
- Morpheus AI Engine and MLflow plugin charts: Removed from chart bundler (`bundler.sh`) and Terraform (`terraform/aws/`). These were separate optional charts (never part of the `graphistry-helm` chart), unmaintained since 2023. Removed `enable-morpheus` and `ngc-api-key` Terraform variables. Removed `morpheus-docs.rst` and `morpheus-mlflow-docs.rst` from Sphinx docs.

### Added

- Configurable StorageClass: Extended `global.storageClassNameOverride` to single-node mode. All PVCs now use a single configurable SC name (default: `retain-sc`). Platforms with pre-registered StorageClasses (e.g. Tanzu/vSphere) can set their own SC name without modifying templates.
- Tanzu/vSphere Deployment Guide: New README and example values for deploying on VMware Tanzu Kubernetes Grid with vSphere CSI storage, GPU Operator driver install, vGPU/passthrough architecture documentation, PSA configuration, and CUDA driver compatibility table.
- k3s Deployment Guide: Expanded README with GPU Operator options (operator-installed vs host driver), CUDA driver compatibility table, GPU verification steps, and storage cleanup commands.
- Grafana Dashboard Documentation: Added DCGM Exporter and Node Exporter Full dashboard paths to GKE, Tanzu, and k3s guides.
- DCGM GPU Metrics Workaround: Documented fix for GKE (COS profiling module incompatibility) and Tanzu (vGPU environments) using GPU Operator's DCGM exporter as alternative scrape target.
- GKE R570 Driver Install: New section for manual R570 DaemonSet deployment with kernel version validation, replacing GKE's default R535 (CUDA 12.2 max) and latest R580 (CUDA 13.x only).
- GKE Cluster Create: Added flag explanations for gpu-driver-version=disabled, machine-type n1-highmem-8, and UBUNTU_CONTAINERD image type.
- GKE Telemetry: Added service path table and access instructions for Grafana, Prometheus, and Jaeger endpoints.
- Troubleshooting Guide: New comprehensive troubleshooting, debugging, and verification guide (`charts/values-overrides/examples/troubleshooting.md`) covering all 11 deployment stages with verified commands, expected sample outputs from a live k3s deployment, service dependency chain documentation, and GPU/telemetry diagnostics. Referenced from all platform READMEs.

### Changed

- StorageClass: `uploads-files` PVC switched from `uploadfiles-sc` (Delete) to `retain-sc` (Retain). Upload data contains permanent processed files and should survive redeployments.
- Default CUDA version: `11.4` -> `12.8` in base values.yaml.
- Default image tag: `latest` -> `v2.45.11` in base values.yaml.
- DCGM exporter image: `3.3.5-3.4.1-ubuntu22.04` -> `4.2.3-4.1.1-ubuntu22.04` in telemetry values.
- GPU Operator version: `v24.9.0` -> `v25.10.1` for GKE, added `RUNTIME_CONFIG_SOURCE=file` for containerd 2.0+ and `NVIDIA_RUNTIME_SET_AS_DEFAULT=true`.
- GKE machine type: `n1-highmem-4` -> `n1-highmem-8` (4 vCPUs caused PGO backup pods to stay Pending).
- GKE example values: Consolidated `default_gke_values.yaml` and `gke_values.yaml` into single `gke_example_values.yaml`.
- Telemetry Config: Moved `telemetryStack` under `global:` in GKE and Tanzu example values for correct Helm subchart propagation.
- Postgres Operator install: Changed from `helm upgrade -i postgres-operator ./charts-aux-bundled/postgres-operator` to `helm install pgo ./charts-aux-bundled/pgo`.
- NGINX Ingress: Changed from remote repo fetch to local bundled chart (`./charts-aux-bundled/ingress-nginx`).
- Install order: Replaced `helm install graphistry-resources` step with `kubectl apply -f retain-sc.yaml` in all platform guides.
- Chart Bundler Dependency Upgrades: dask-kubernetes-operator (2023.7.2 -> 2025.7.0), cert-manager (v1.10.1 -> v1.19.3), eck-operator (2.5.0 -> 3.3.0), dcgm-exporter (3.0.0 -> 4.7.1), jupyterhub (2.0.0 -> 4.3.2), ingress-nginx (4.4.0 -> 4.14.3), pgo (git clone -> OCI helm pull v6.0.0).
- Charts version upgrade: graphistry-helm, telemetry (0.4.0 -> 0.4.1), postgres-cluster (0.7.4 -> 0.7.5).
- Cleaned up redundant inline comments in base values.yaml.
- Sphinx docs: Full refresh (v0.3.7 -> v0.4.1). Renamed Quick Start Guide to "10 Minutes to Graphistry on Kubernetes". Rewrote with GPU Operator, modern deployment flow, StorageClass configuration, Docker Hub access with Graphistry Support contact link. Added dedicated StorageClass guide (`configure-storageclass.rst`). Added comprehensive Telemetry guide (`telemetry-docs.rst`) covering local stack, cloud mode, cluster mode, OTEL Collector pipelines, component configuration, and resource requirements. Added Docker Access section to `graphistry-helm-docs.rst` and `Chart.yaml`. Updated values override docs with telemetry config and `storageClassNameOverride`. Removed outdated graphistry-resources and Morpheus references. Updated Sphinx dependencies (`requirements.txt`).
- Removed `graphistry-resources` service from `dev-compose/docker-compose.yml` and `.github/workflows/dev-cluster-deployment.yaml`.
- Removed `graphistry-resource-cd.yaml` ArgoCD Application (referenced deleted chart).

### Fixed

- Postgres Backup PVC: Fixed pgBackRest backup volume defaulting to `retain-sc-{{ .Release.Namespace }}` (e.g., `retain-sc-graphistry`) which was never created by the `graphistry-helm-resources` chart. Both data and backup volumes now default to `retain-sc`, consistent with Crunchy Data PGO upstream examples.
- GKE Cleanup: Fixed PGO release name (`postgres-operator` -> `pgo`), added missing GPU Operator uninstall, consolidated namespace deletes, removed redundant `kubectl get ns` and `--watch` on verify step.
- k3s Cleanup: Fixed PGO release name (`postgres-operator` -> `pgo`), added missing GPU Operator uninstall and `gpu-operator` namespace deletion, added PV/PVC/StorageClass cleanup commands.
- Postgres init containers: Replaced `k8s-wait-for pod -lapp=postgres` with [`pg_isready`](https://www.postgresql.org/docs/current/app-pg-isready.html) targeting the `postgres-primary` service in nexus, forge-etl-python, pivot, and streamgl-viz templates. The old approach matched any pod with the `app=postgres` label, including backup CronJob pods in Error or Completed state, which could cause init containers to pass or fail incorrectly. `pg_isready` checks actual database connection readiness, is immune to backup pod status, and removes the third-party `groundnuty/k8s-wait-for` dependency for these four services.
- Postgres backup schedule collision: Changed incremental backup schedule from `*/30 * * * *` (runs at :00 and :30) to `15,45 * * * *` (runs at :15 and :45). The old schedule collided with the differential backup at `0 3 * * *` (3:00 AM), causing PGO to create two backup jobs simultaneously. The new schedule maintains the same 30-minute frequency while avoiding the :00 marks used by full and differential backups.
- Dask nodeSelector: Fixed `dask-scheduler-deployment.yaml`, `dask-cuda-worker-daemonset.yaml`, and `NOTES.txt` referencing `.Values.multiNode` instead of `.Values.global.multiNode`. Since `multiNode` is defined under `global:` in values.yaml, the incorrect reference resolved to nil, and `nil == false` evaluates to false in Go templates, causing the nodeSelector block to be silently skipped. On multi-node clusters, this allowed dask-scheduler and dask-cuda-worker pods to land on nodes without GPUs or on different nodes than the data volume, causing Multi-Attach errors on RWO PVCs.

## [Version 0.4.0 - 2025-12-16]

### Breaking

- Remove legacy VGraph/protobuf services: `streamgl-vgraph-etl` and `forge-etl` (TypeScript) deployments removed in favor of `forge-etl-python` (Arrow-based).
- Remove init container dependencies: nginx, notebook, and pivot deployments no longer wait for removed services.
- Remove legacy service configurations from values.yaml: `ForgeETLResources`, `StreamglVgraphResources`, `streamglvgraph`, `forgeetl` sections removed.
- Aligns with Graphistry server v2.45.7+ which removes API v1/v2 support. Users must use PyGraphistry `register(api=3)` with JWT authentication.

### Changed

- Charts version upgrade: graphistry-helm, graphistry-helm-resources, telemetry (0.3.8 -> 0.4.0).
- Postgres cluster chart version upgrade (0.7.3 -> 0.7.4).
- Remove legacy image references from ACR bootstrap and dev-compose scripts.

## [Version 0.3.8 - 2025-01-06]

### Added

- Cluster Deployment: Each Graphistry instance (leader and followers) will be deployed in its own dedicated namespace.
- Shared Volume: All instances can share access to a common volume for a cluster deployment (using NFS as a reference).
- Database Configuration: All instances will point to the leader Postgres DB instance when using cluster deployment.
- OpenTelemetry and Observability Stack: Each instance starts its own OpenTelemetry Collector, but only the leader instance can start the full Observability Stack, including Grafana, Prometheus, Jaeger, Node Exporter, and NVIDIA DCGM Exporter.
- Improve Telemetry Documentation: Updated documentation for cluster deployment, providing better clarity on configuration and usage.
- Redis as a Centralized Service: Redis will now serve all FEP and Nexus instances, including those for followers.
- Charts Version Upgrade: Upgraded Helm chart versions to the latest.

## [Version 0.3.7 - 2025-01-06]

### Added

*   Added CUDA 11.8 / RAPIDS 23.10 support.
*   Added GKE support and guidelines.
*   Added OpenTelemetry support (including Grafana, Prometheus, Jaeger on ArgoCD).
*   Improved Postgres cluster configuration.

## [Version 0.3.6 - 2023-07-25]

### Breaking 🔥
* None
### Added

*   Added optional GAK secret so it doesnt hold up the deployment if the secret is not present


*   Added Bundler for auxiliary charts for airgap deployments.  

*   Added github action for aux charts bundle release.



### Changed

*   Made Dask Kubernetes operator Optional, will deploy standard scheduler/worker if not present

*   Changed Terraform design to use charts from Chart bundle instead of using the charts from the repo directly.
    
### Fixed

*   Dask Kubernetes operator fixed the scheduler bug upstream

*   Fixed hardcoded service name in dask scheduler service spec



## [Version 0.3.5 - 2023-02-13]

### Breaking 🔥
*   Removed the nexus migration job and replaced it with a strategy to rollout our deployment exactly 
    the same way as we do with our docker-compose version.

*   Changed StorageClass name to note be namespaced scoped. 
    This will allow us to use the same storage class for all namespaces.
### Added

*   Added Postgres operator and changed our postgres deployment into an operator controlled PostgresCluster.
    This allows us to use the Postgres operator to manage our Postgres deployment and also allows us to use the Postgres operator to manage our Postgres backups, as well as giving us the option to run postgres in a Highly Available configuration for redundancy. The Operator also allows us to backup our Postgres database to S3/GCS/Azure storage and other S3 compatible storage. As well as giving us the option to encrypt communication between our database and our services.


*   Added ArgoCD with a "app of apps" deployment pattern to manage our deployment. This gives us the 
    the ability to manage our deployment with a gitops pattern.     

*   Created Docs -> [Graphistry Helm Docs](https://readthedocs.org/projects/graphistry-helm/)

*   Added volume names to automatically bind PVC to PV after provisioning upon redeployment

*   Added a volume selector to postgres cluster to bind the PVC to the PV after provisioning upon redeployment

*   Added ability to configure Forge ETL python resource limits and number of workers

*   Added Morpheus and MLFlow plugin charts 



### Changed

*   Made network policy optional, with a strict mode and default mode set to false as default (No policy in use by default).

*   Removed the nexus migration job and replaced it with a strategy to rollout our deployment exactly 
    the same way as we do with our docker-compose version.
    
*   Reorganized the values.yaml override file to be more readable.

*   Adjusted the PVCs for the charts to be more persistent.
    
### Fixed

*   Fixed the pvc retention issue by setting the pvc name in the values.yaml so the PV and PVC automatically bind after provisioning upon redeployment
