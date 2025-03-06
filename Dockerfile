FROM alpine:latest

LABEL org.opencontainers.image.source=https://github.com/ivank/trivy-post
LABEL org.opencontainers.image.description="Trivy Post"
LABEL org.opencontainers.image.licenses=MIT

ARG TRIVY_VERSION=0.60.0
ARG GH_VERSION=2.10.1

ARG TRIVY_HOME=/trivy
RUN mkdir $TRIVY_HOME &&
ENV TRIVY_HOME=${TRIVY_HOME}
ENV PATH="${TRIVY_HOME}:${PATH}"


RUN apk add --no-cache curl bash jq
RUN curl --location https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz | tar x -z -C $TRIVY_HOME

RUN curl --location https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz | tar --strip-components=2 x -z -C /usr/local/bin gh_${GH_VERSION}_linux_amd64/bin/gh

COPY ./trivy-post.sh /builder/trivy-post.sh

ENTRYPOINT ["bash","/builder/trivy-post.sh"]
