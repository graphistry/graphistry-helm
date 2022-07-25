## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

    helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
graphistry-helm` to see the charts.

To install the Graphistry-Helm-Chart chart:

    helm install my-graphistry-chart graphistry-helm/graphistry-helm-chart

To uninstall the chart:

    helm delete my-graphistry-chart



