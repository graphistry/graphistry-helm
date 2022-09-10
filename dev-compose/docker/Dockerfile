FROM ubuntu:18.04

COPY ./helm-dev-setup-deploy.sh setup_deploy.sh
COPY ./make_docker_secret.sh make_secret.sh
COPY ./copy-aws-creds.sh copy-aws-creds.sh

RUN apt-get update -y && \ 
    apt-get install -y  wget apt-utils curl unzip \
    ca-certificates apt-transport-https lsb-release gnupg

RUN add-apt-repository ppa:rmescandon/yq && \
    apt update && \
    apt install yq -y


RUN echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list

RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | \ 
    gpg --dearmor | \
    tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install azure-cli
RUN az version

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" &&\
    unzip awscliv2.zip && \ 
    ./aws/install -i /usr/local/aws-cli -b /usr/local/bin && \
    aws --version

ARG KUBE_VERSION="v1.18.20" HELM_VERSION="v3.6.1" 

RUN wget -q https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    kubectl version --client

RUN wget -q https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -O - | tar -xz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64 && \
    helm version

#RUN helm repo add graphistry-helm https://graphistry.github.io/graphistry-helm/

CMD tail -f /dev/null

#ENTRYPOINT ["/entrypoint.sh"]