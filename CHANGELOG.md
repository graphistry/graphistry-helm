
# graphistry-helm Version Release Notes

## Changelog

All notable changes to the graphistry-helm repo are documented in this file. Additional Graphistry components are tracked in the main [Graphistry major release history documentation](https://graphistry.zendesk.com/hc/en-us/articles/360033184174-Enterprise-Release-List-Downloads).

The changelog format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and all PyGraphistry-specific breaking changes are explictly noted here.

## [Development]
*   Working on fixing the Top level persistence for jupyter Notebooks, currently it is persistent inside the different directories but top level resets on redeployment.

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
