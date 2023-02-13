# Minimal makefile for Sphinx documentation
#

# You can set these variables from the command line, and also
# from the environment for the first two.
SPHINXOPTS    ?=
SPHINXBUILD   ?= sphinx-build
SOURCEDIR     = source
BUILDDIR      = build
FRIGATE	      ?= frigate gen --no-credits --no-deps
FRIGATE_OUTPUT = rst #can be html, md, rst

# Put it first so that "make" without argument is like "make help".
help:
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O) &&\
	printf "\n" &&\
	echo "frigate:" &&\
	$(FRIGATE) --help

.PHONY: help Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)



#install requirements

deps:
	pip install -r requirements.txt

# Generate the docs with frigate
frigate:
	$(FRIGATE) ../charts/graphistry-helm -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/graphistry-helm-docs.$(FRIGATE_OUTPUT) && \
	$(FRIGATE) ../charts/graphistry-helm-resources -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/graphistry-resources-docs.$(FRIGATE_OUTPUT) && \
	$(FRIGATE) ../charts/k8s-dashboard -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/k8s-dashboard-docs.$(FRIGATE_OUTPUT) && \
	$(FRIGATE) ../charts/postgres-cluster -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/postgres-cluster-docs.$(FRIGATE_OUTPUT) && \
	$(FRIGATE) ../chart-bundle/Morpheus-ai-engine -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/morpheus-docs.$(FRIGATE_OUTPUT) && \
	$(FRIGATE) ../chart-bundle/NVIDIA-morpheus-mlflow-plugin -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/morpheus-mlflow-docs.$(FRIGATE_OUTPUT)
#$(FRIGATE) ../charts/ingress-nginx -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/ingress-nginx-docs.$(FRIGATE_OUTPUT) 
#$(FRIGATE) ../charts/graphistry-jupyter-hub -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/graphistry-jupyter-hub-docs.$(FRIGATE_OUTPUT) && \
#$(FRIGATE) ../charts/kube-prometheus-stack -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/kube-prometheus-stack-docs.$(FRIGATE_OUTPUT) 
#$(FRIGATE) ../charts/postgres-operator -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/postgres-operator-docs.$(FRIGATE_OUTPUT) && \
#$(FRIGATE) ../charts/dask-kubernetes-operator -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/dask-kubernetes-operator-docs.$(FRIGATE_OUTPUT) && \
#$(FRIGATE) ../charts/cert-manager -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/cert-manager-docs.$(FRIGATE_OUTPUT) && \
#$(FRIGATE) ../charts/argo-cd -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/argo-cd-docs.$(FRIGATE_OUTPUT) && \