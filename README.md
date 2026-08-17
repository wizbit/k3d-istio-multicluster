# K3d Istio MultiCluster

This repo contains simple scripts to boot one or more k3d clusters with Istio & ArgoCD.

It also connects all the clusters in multi-primary istio ambient mode.

It installs ArgoCD only into the primary cluster, for a hub-spoke setup.

## Prerequisites

Install the following before starting

* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [k3d](https://k3d.io/stable/#releases)
* [docker](https://www.docker.com/)
* [helm](https://helm.sh/docs/intro/install/)
* [istioctl](https://istio.io/latest/docs/ambient/getting-started/)

## To run

```shell
./boot.sh -c <number-of-clusters>
```

## To tear down

This will delete all clusters

```shell
./destroy.sh
```

## Demo projects

[Bootstrap cluster with Traefik, Cert-Manager & Keda](https://github.com/wizbit/k8s-bootstrap)
```shell
kubectl apply -f https://raw.githubusercontent.com/wizbit/k8s-bootstrap/refs/heads/main/bootstrap/system.yaml
```