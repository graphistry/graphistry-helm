# graphistry-helm Version Release Notes

## Version 0.3.5


*   Converted Postgres to StatefulSet to add in persistence.

*   Added Dask operator to control our Dask cuda Scheduler and Workers. 
    This will allow us to scale up and down the number of workers as needed. 
    Temporary workaround for service name issue with the operator, 
    currently unable to set the service name to `dask-scheduler` in the scheduler.service spec 
    so we are using a service named `dask-scheduler` instead.


*   Reorganized the values.yaml override file to be more readable.
*   Adjusted the PVCs for the charts to be more persistent.