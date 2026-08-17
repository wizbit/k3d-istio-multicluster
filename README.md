# K3d Istio MultiCluster

This repo contains simple scripts to boot two k3d clusters with Istio, Traefik, Keda & Cert Manager.

It also connects the two clusters in multi-primary istio setup.

## Prerequisites

Install the following before starting

* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [k3d](https://k3d.io/stable/#releases)
* [docker](https://www.docker.com/)
* [helm](https://helm.sh/docs/intro/install/)
* [istioctl](https://istio.io/latest/docs/ambient/getting-started/)

## To run

```shell
./boot.sh <number-of-clusters>
```

## To tear down

This will delete both clusters

```shell
./destroy.sh
```

## Install Helloworld example

This will install the helloworld example into *n* clusters. This example contains a deployment, a global service and a
failover to other clusters. As well as a curl service for testing connection. It also installs a Traefik IngressRoute
into the first cluster ([helloworld.docker.localhost](https://helloworld.docker.localhost)).

```shell
./install-helloworld.sh <number-of-clusters>
```
