FROM registry.access.redhat.com/ubi8/openjdk-8-runtime:latest
LABEL maintainer="Ken Moini" \
      description="Bamboo Agent Container Image"

ENV BAMBOO_USER=bamboo
ENV BAMBOO_GROUP=bamboo

ENV BAMBOO_USER_HOME=/home/${BAMBOO_USER}
ENV BAMBOO_AGENT_HOME=${BAMBOO_USER_HOME}/bamboo-agent-home
ENV HOME ${BAMBOO_USER_HOME}

ENV INIT_BAMBOO_CAPABILITIES=${BAMBOO_USER_HOME}/init-bamboo-capabilities.properties
ENV BAMBOO_CAPABILITIES=${BAMBOO_AGENT_HOME}/bin/bamboo-capabilities.properties

ARG BAMBOO_VERSION=7.2.4
ARG DOWNLOAD_URL=https://packages.atlassian.com/maven-closedsource-local/com/atlassian/bamboo/atlassian-bamboo-agent-installer/${BAMBOO_VERSION}/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar
ENV AGENT_JAR=${BAMBOO_USER_HOME}/atlassian-bamboo-agent-installer.jar

USER root

# Create Bamboo home directory, user, and group
RUN set -x && \
    mkdir -p ${BAMBOO_USER_HOME} && \
    groupadd -g 1001 ${BAMBOO_GROUP} && \
    adduser -u 1001 -g 1001 -d ${BAMBOO_USER_HOME} -r ${BAMBOO_USER} && \
    chown -R ${BAMBOO_USER} ${BAMBOO_USER_HOME}

# Update and install basic packages
RUN set -x && \
    microdnf update -y && \
    microdnf install -y \
      curl \
      git \
      wget \
      procps-ng \
      podman \
      buildah \
      skopeo \
  	&& microdnf clean all \
  	&& rm -rf /var/cache/yum

# Switch to the bamboo user
WORKDIR ${BAMBOO_USER_HOME}
USER ${BAMBOO_USER}

# Download the agent
RUN set -x && \
    curl -L --silent --output ${AGENT_JAR} ${DOWNLOAD_URL} && \
    mkdir -p ${BAMBOO_USER_HOME}/bamboo-agent-home/bin && \
    # commence bad hacky shit...
    chmod -R 777 ${BAMBOO_USER_HOME}

# Copy needed files
COPY --chown=bamboo:bamboo scripts/bamboo-update-capability.sh bamboo-update-capability.sh
COPY --chown=bamboo:bamboo scripts/runAgent.sh runAgent.sh

# Set Java Configuration
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 1.8" ${JAVA_HOME}/bin/java

# Set Git Config
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.git.executable" /usr/bin/git

# Set some other executable config caps
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.bash" /bin/bash
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.sh" /bin/sh
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.id" /bin/id
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.wget" /bin/wget
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.curl" /bin/curl
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.podman" /bin/podman
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.buildah" /bin/buildah
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.command.skopeo" /bin/skopeo

# Entry into the agent initiation script
ENTRYPOINT ["./runAgent.sh"]