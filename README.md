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
./boot.sh
./install-istio.sh
./install-helloworld.sh
```

## To tear down

This will delete both clusters

```shell
./destroy.sh
```

## To run 1-3 clusters

```shell
export CLUSTER_COUNT=3 # number of clusters
./boot.sh
./install-istio.sh
./install-helloworld.sh
```