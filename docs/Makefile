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
	@$(SPHINXBUILD) -M help "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

.PHONY: help Makefile

# Catch-all target: route all unknown targets to Sphinx using the new
# "make mode" option.  $(O) is meant as a shortcut for $(SPHINXOPTS).
%: Makefile
	@$(SPHINXBUILD) -M $@ "$(SOURCEDIR)" "$(BUILDDIR)" $(SPHINXOPTS) $(O)

# Generate the docs with frigate
frigate:
	$(FRIGATE) ../charts/graphistry-helm -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/graphistry-helm-docs.$(FRIGATE_OUTPUT) && \
	$(FRIGATE) ../charts/graphistry-helm-resources -o $(FRIGATE_OUTPUT) > ./$(SOURCEDIR)/graphistry-resources-docs.$(FRIGATE_OUTPUT)

