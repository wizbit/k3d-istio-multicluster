#!/usr/bin/env bash

helm repo add kedacore https://kedacore.github.io/charts
help repo add traefik https://traefik.github.io/charts

helm repo update

install_basic() {
  context="k3d-$1"

  helm install --kube-context "${context}" cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true

  helm install --kube-context "${context}" keda kedacore/keda --namespace keda --create-namespace
  helm install --kube-context "${context}" http-add-on kedacore/keda-add-ons-http --namespace keda

  helm install --kube-context "${context}" traefik traefik/traefik --namespace traefik --create-namespace --values traefik.yaml
}


k3d cluster create cluster1 \
  --port 80:80@loadbalancer \
  --port 443:443@loadbalancer \
  --port 8000:8000@loadbalancer \
  --k3s-arg "--disable=traefik@server:0" \
  --k3s-arg "--tls-san=k3d-cluster1-server-0@server:*" \
  --network k3d-mesh

k3d cluster create cluster2 \
  --port 9080:80@loadbalancer \
  --port 9443:443@loadbalancer \
  --port 9000:8000@loadbalancer \
  --k3s-arg "--disable=traefik@server:0" \
  --k3s-arg "--tls-san=k3d-cluster2-server-0@server:*" \
  --network k3d-mesh

install_basic cluster1
install_basic cluster2

