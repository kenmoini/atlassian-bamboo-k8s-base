FROM adoptopenjdk:11-jdk-hotspot-focal
LABEL maintainer="Ken Moini" \
      description="Bamboo Agent Container Image"

ENV BAMBOO_USER=bamboo
ENV BAMBOO_GROUP=bamboo

ENV BAMBOO_USER_HOME=/home/${BAMBOO_USER}
ENV BAMBOO_AGENT_HOME=${BAMBOO_USER_HOME}/bamboo-agent-home

ENV INIT_BAMBOO_CAPABILITIES=${BAMBOO_USER_HOME}/init-bamboo-capabilities.properties
ENV BAMBOO_CAPABILITIES=${BAMBOO_AGENT_HOME}/bin/bamboo-capabilities.properties

USER root

RUN set -x && \
     addgroup ${BAMBOO_GROUP} && \
     adduser ${BAMBOO_USER} --home ${BAMBOO_USER_HOME} --ingroup ${BAMBOO_GROUP} --disabled-password

RUN set -x && \
     apt-get update && \
     apt-get install -y --no-install-recommends \
          curl \
          tini \
          git \
          wget \
     && \
     rm -rf /var/lib/apt/lists/*

WORKDIR ${BAMBOO_USER_HOME}
USER ${BAMBOO_USER}

ARG BAMBOO_VERSION=8.0.0
ARG DOWNLOAD_URL=https://packages.atlassian.com/maven-closedsource-local/com/atlassian/bamboo/atlassian-bamboo-agent-installer/${BAMBOO_VERSION}/atlassian-bamboo-agent-installer-${BAMBOO_VERSION}.jar
ENV AGENT_JAR=${BAMBOO_USER_HOME}/atlassian-bamboo-agent-installer.jar

RUN set -x && \
     curl -L --silent --output ${AGENT_JAR} ${DOWNLOAD_URL} && \
     mkdir -p ${BAMBOO_USER_HOME}/bamboo-agent-home/bin

# Copy needed files
COPY --chown=bamboo:bamboo scripts/bamboo-update-capability.sh bamboo-update-capability.sh
COPY --chown=bamboo:bamboo scripts/runAgent.sh runAgent.sh

# Set Java Configuration
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.jdk.JDK 1.8" ${JAVA_HOME}/bin/java

# Set Git Config
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.git.executable" /usr/bin/git

# Entry into the agent initiation script
ENTRYPOINT ["./runAgent.sh"]