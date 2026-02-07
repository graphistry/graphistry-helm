
# graphistry-helm Version Release Notes

## Changelog

All notable changes to the graphistry-helm repo are documented in this file. Additional Graphistry components are tracked in the main [Graphistry major release history documentation](https://graphistry.zendesk.com/hc/en-us/articles/360033184174-Enterprise-Release-List-Downloads).

The changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and all PyGraphistry-specific breaking changes are explictly noted here.

## [Development]
*   Working on fixing the Top level persistence for jupyter Notebooks, currently it is persistent inside the different directories but top level resets on redeployment.

## [Version 0.4.1 - 2026-02-05]

### Added

- Tanzu/vSphere Deployment Guide: New README and example values for deploying on VMware Tanzu Kubernetes Grid with vSphere CSI storage, GPU Operator driver install, vGPU/passthrough architecture documentation, PSA configuration, and CUDA driver compatibility table.
- k3s Deployment Guide: Expanded README with GPU Operator options (operator-installed vs host driver), CUDA driver compatibility table, GPU verification steps, and storage cleanup commands.
- Namespace-scoped StorageClass: New `retain-sc-<namespace>` template in graphistry-helm-resources for multi-tenant isolation of postgres backup repos on single clusters.
- Grafana Dashboard Documentation: Added DCGM Exporter and Node Exporter Full dashboard paths to GKE, Tanzu, and k3s guides.
- DCGM GPU Metrics Workaround: Documented fix for GKE (COS profiling module incompatibility) and Tanzu (vGPU environments) using GPU Operator's DCGM exporter as alternative scrape target.
- GKE R570 Driver Install: New section for manual R570 DaemonSet deployment with kernel version validation, replacing GKE's default R535 (CUDA 12.2 max) and latest R580 (CUDA 13.x only).
- GKE Cluster Create: Added flag explanations for gpu-driver-version=disabled, machine-type n1-highmem-8, and UBUNTU_CONTAINERD image type.
- GKE Telemetry: Added service path table and access instructions for Grafana, Prometheus, and Jaeger endpoints.

### Changed

- Default CUDA version: `11.4` -> `12.8` in base values.yaml.
- Default image tag: `latest` -> `v2.45.11` in base values.yaml.
- DCGM exporter image: `3.3.5-3.4.1-ubuntu22.04` -> `4.2.3-4.1.1-ubuntu22.04` in telemetry values.
- GPU Operator version: `v24.9.0` -> `v25.10.1` for GKE, added `RUNTIME_CONFIG_SOURCE=file` for containerd 2.0+ and `NVIDIA_RUNTIME_SET_AS_DEFAULT=true`.
- GKE machine type: `n1-highmem-4` -> `n1-highmem-8` (4 vCPUs caused PGO backup pods to stay Pending).
- GKE example values: Consolidated `default_gke_values.yaml` and `gke_values.yaml` into single `gke_example_values.yaml`.
- Telemetry Config: Moved `telemetryStack` under `global:` in GKE and Tanzu example values for correct Helm subchart propagation.
- Postgres Operator install: Changed from `helm upgrade -i postgres-operator ./charts-aux-bundled/postgres-operator` to `helm install pgo ./charts-aux-bundled/pgo`.
- NGINX Ingress: Changed from remote repo fetch to local bundled chart (`./charts-aux-bundled/ingress-nginx`).
- Postgres Cluster install: Removed `--set global.provisioner` (now handled by graphistry-resources).
- GKE install order: Reordered to Dask Operator -> Postgres Operator -> Postgres Cluster -> Graphistry Resources (storage classes must exist before postgres pods can bind).
- Chart Bundler Dependency Upgrades: dask-kubernetes-operator (2023.7.2 -> 2025.7.0), cert-manager (v1.10.1 -> v1.19.3), eck-operator (2.5.0 -> 3.3.0), dcgm-exporter (3.0.0 -> 4.7.1), jupyterhub (2.0.0 -> 4.3.2), ingress-nginx (4.4.0 -> 4.14.3), pgo (git clone -> OCI helm pull v6.0.0).
- Charts version upgrade: graphistry-helm, graphistry-helm-resources, telemetry (0.4.0 -> 0.4.1).
- Cleaned up redundant inline comments in base values.yaml.

### Fixed

- GKE Cleanup: Fixed PGO release name (`postgres-operator` -> `pgo`), added missing GPU Operator uninstall, consolidated namespace deletes, removed redundant `kubectl get ns` and `--watch` on verify step.
- k3s Cleanup: Fixed PGO release name (`postgres-operator` -> `pgo`), added missing GPU Operator uninstall and `gpu-operator` namespace deletion, added PV/PVC/StorageClass cleanup commands.
- Graphistry Resources: Added missing `retain-sc-<namespace>` StorageClass. Previously, multiple single-node deployments in different namespaces on the same cluster would conflict because postgres-cluster expects a namespace-scoped storage class for pgBackRest backup repos.

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
