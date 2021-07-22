# Atlassian Bamboo Agent Container Image for Kubernetes/OpenShift

_*This is the most cursed thing ever devised.  Please get a better SCM-CI/CD-DevOps platform...like, Jenkins is even better than this shit...*_

> How do you run Atlassian Agents and Builds on a Kubernetes platform like OpenShift?  First, draw a pentogram...

## Base Container Image

This repository has a Containerfile (like a Dockerfile, less branding) that can be used to build a RHEL 8 UBI base image to run the Atlassian Agent.  Build it with the following:

```bash
sudo podman build -f Containerfile -t atlassian-agent-image .
```

Alternatively, you can pull the image from Quay.io: quay.io/kenmoini/atlassian-bamboo-k8s-image

There's not much in the image base, for things like Maven and NodeJS, etc you'll need to add those on top - this is an example for a Maven layer:

```
FROM quay.io/kenmoini/atlassian-bamboo-k8s-image:latest

# Switch to root user to install new packages
USER root
RUN microdnf update -y && \
    microdnf install maven -y && \
  	microdnf clean all && \
  	rm -rf /var/cache/yum

# Switch to Bamboo User to set config in home dir
USER ${BAMBOO_USER}
RUN ${BAMBOO_USER_HOME}/bamboo-update-capability.sh "system.builder.mvn3.Maven 3.3" /usr/share/maven
```

You may need to configure additional capabilities of the Agent: https://confluence.atlassian.com/bamboo/configuring-capabilities-289277148.html

## Running on OpenShift

Running Atlassian Bamboo Agents and Builds on Openshift is likely not a good idea - the application requires a lot of permissions that could easily compromise your OpenShift cluster if Bamboo or your build/supply chain were to be compromised.  You have been warned...

In case you have a penchant for pain, here's how you go about doing it anyway...

### Apply OpenShift Manifests

First you'll need to create a Project, Roles, RoleBindings, and SCC definitions in your cluster - you can do this by running:

```bash
oc apply -f openshift/01-project.yaml
oc apply -f openshift/02-serviceaccount.yaml
oc apply -f openshift/03-scc.yaml
oc apply -f openshift/04-scc-use-role.yaml
oc apply -f openshift/05-scc-sb.yaml
```

> *_NOTE:_* The SecurityContextConstraints that are defined basically give the ServiceAccount the ability to run any workload with some root permissions - apply at your own risk!

#### Deployment-based Agent

Now, if you'd like to just use a specific set of Agents provisioned on a cluster, you can also use the deployment objects in the `openshift/` folder - just make sure to edit the needed parts, specifically around `spec.container.args`

To run the agent deployment as it sits, you need to disable Remote Agent Token Verification - or you can pass the token in via an environment variable called `$BAMBOO_SECURITY_TOKEN`.

If you'd rather manage Kubernetes agents from Bamboo, you'll need some sort of plugin.

### Install Bamboo Kubernetes Plugin

So I've tried the Per Build Container project by Atlassian and it didn't work - I suggest buying the "Kubernetes (Agents) for Bamboo" by Windtunnel Technologies.

#### Configure Windtunnel Technologies Plugin

Once you install the Windtunnel Technologies Kubernetes plugin (Bamboo Administration > Manage Apps > Search for "kubernetes"), you will find additional Administration Menu items.

Navigate in the Bamboo Administration panel to "Kubernetes Agents > Clusters" - you'll need to create and define your K8s/OpenShift cluster.  For an OpenShift cluster it'd be something like `https://api.CLUSTER_NAME.BASE_DOMAIN:6443`.  Use `bamboo-agent` as the Namespace, and for Authentication method use a Token that you can get via this command: `oc serviceaccounts get-token bamboo-sa`.  Click "Test Connection" and then "Save".

Next you'll need to create an Image, like this Base Image.  Navigate in the Bamboo Administration panel to "Kubernetes Agents > Images" and create an Image or two, you could even use `quay.io/kenmoini/atlassian-bamboo-k8s-image`

With a Cluster and an Image or two defined, you can create an agent Instance - navigate in the Bamboo Administration panel to "Kubernetes Agents > Instances"

Define an Instance with the Cluster and an Image - you can set the "Pool" to whatever, I set to "Automatic."  Expand the "Advanced Options" and you can change the Pod size created, but importantly you need to set the following "Spec merge":

```yaml
serviceAccount: bamboo-sa
securityContext:
  runAsUser: 0
  runAsGroup: 0
  fsGroup: null
dnsPolicy: Default
dnsConfig:
  nameservers: null
  searches: 
    - kemo.labs
```

You may have to set your own DNS servers/search domains to replace those, which are mine and not yours.  _*Also, the securityContext runs the container as root:root!*_

Another note: the plugin does a merge of the definitions, which for some reason defaults to two Google DNS servers and defining another set won't override, just merge into the dnsConfig.nameservers list...which is very annoying...this is why dnsPolicy is set to Default to inherit the cluster-wide DNS configuration.

Click "Save and Start" - you should see the Pod spin up on your OpenShift cluster now.