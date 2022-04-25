FROM ubuntu:18.04

RUN apt-get update -y && \ 
    apt-get install -y  wget apt-utils curl unzip

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" &&\
    unzip awscliv2.zip && \ 
    ./aws/install -i /usr/local/aws-cli -b /usr/local/bin && \
    aws --version

ARG KUBE_VERSION="v1.18.20" HELM_VERSION="v3.6.1" 

RUN wget -q https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl 

RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64 && \
    helm version

RUN helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/
