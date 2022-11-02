# graphistry-helm Version Release Notes

## Version 0.3.5


*   Added Postgres operator and changed our postgres deployment into an operator controlled PostgresCluster.
    This allows us to use the Postgres operator to manage our Postgres deployment and also allows us to use the Postgres operator to manage our Postgres backups, as well as giving us the option to run postgres in a Highly Available configuration for redundancy. The Operator also allows us to backup our Postgres database to S3/GCS/Azure storage and other S3 compatible storage. As well as giving us the option to encrypt communication between our database and our services.

*   Added Dask operator to control our Dask cuda Scheduler and Workers. 
    This will allow us to scale up and down the number of workers as needed. 
    Temporary workaround for service name issue with the operator, 
    currently unable to set the service name to `dask-scheduler` in the scheduler.service spec 
    so we are using a service named `dask-scheduler` instead.

*   Added ArgoCD with a "app of apps" deployment pattern to manage our deployment. This gives us the 
    the ability to manage our deployment with a gitops pattern.     

*   Reorganized the values.yaml override file to be more readable.
*   Adjusted the PVCs for the charts to be more persistent.

*   Removed the nexus migration job and replaced it with a strategy to rollout our deployment exactly 
    the same way as we do with our docker-compose version.

*   Created Docs -> [Graphistry Helm Docs](https://readthedocs.org/projects/graphistry-helm/)

*   Added volume names to automatically bind PVC to PV after provisioning upon redeployment

*   Added a volume selector to postgres cluster to bind the PVC to the PV after provisioning upon redeployment

*   Made network policy optional, with a strict mode and default mode set to false as default (No policy in use by default).

*   Added ability to configure Forge ETL python resource limits and number of workers

*   Added Morpheus and MLFlow plugin charts 