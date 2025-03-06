FROM alpine:latest

LABEL org.opencontainers.image.source=https://github.com/ivank/trivy-post
LABEL org.opencontainers.image.description="Trivy Post"
LABEL org.opencontainers.image.licenses=MIT

ARG GH_VERSION=2.10.1
ARG BERGLAS_VERSION=2.0.6

RUN apk add --no-cache curl bash openssl jq
RUN curl --location https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz | tar --strip-components=2 -xzC /usr/local/bin gh_${GH_VERSION}_linux_amd64/bin/gh
RUN curl --location https://github.com/GoogleCloudPlatform/berglas/releases/download/v${BERGLAS_VERSION}/berglas_${BERGLAS_VERSION}_linux_amd64.tar.gz | tar -xzC /usr/local/bin

COPY ./trivy-post.sh /builder/trivy-post.sh

ENTRYPOINT ["bash","/builder/trivy-post.sh"]
