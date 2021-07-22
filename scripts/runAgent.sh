#!/bin/bash
#set -x
set -euo pipefail

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export LANGUAGE=C.UTF-8

#echo "whoami: $(whoami)"
#echo "id: $(id)"
#echo "ls User Home:"
#ls -al $BAMBOO_USER_HOME
#echo "ls Agent Home:"
#ls -al $BAMBOO_AGENT_HOME
#echo -e "\n"

if [ -z ${1+x} ]; then
    echo "Please run the Docker image with Bamboo URL as the first argument"
    exit 1
fi

if [ ! -f ${BAMBOO_CAPABILITIES} ]; then
    mkdir -p ${BAMBOO_AGENT_HOME}/bin
    chmod 777 ${BAMBOO_AGENT_HOME}/bin
    cp ${INIT_BAMBOO_CAPABILITIES} ${BAMBOO_CAPABILITIES}
fi

if [ -z ${SECURITY_TOKEN+x} ]; then   
    exec java ${VM_OPTS:-} -jar "${AGENT_JAR}" "${1}/agentServer/"
else 
    exec java ${VM_OPTS:-} -jar "${AGENT_JAR}" "${1}/agentServer/" -t "${SECURITY_TOKEN}"
fi 