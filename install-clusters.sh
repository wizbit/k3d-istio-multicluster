#!/usr/bin/env bash

CLUSTER_COUNT="${1:-1}"

if [ "$CLUSTER_COUNT" -gt "3" ]; then
  echo "A maximum cluster count of 3 is allowed"
  exit 1
fi

helm repo add kedacore https://kedacore.github.io/charts
help repo add traefik https://traefik.github.io/charts

helm repo update

install_basic() {
  context="k3d-$1"

  # Install Gateway API CRDs from the Standard channel.
  kubectl apply --context "${context}" -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml

  helm upgrade --install --kube-context "${context}" cert-manager oci://quay.io/jetstack/charts/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set crds.enabled=true

  helm upgrade --install --kube-context "${context}" keda kedacore/keda --namespace keda --create-namespace
  helm upgrade --install --kube-context "${context}" http-add-on kedacore/keda-add-ons-http --namespace keda

  helm upgrade --install --kube-context "${context}" traefik traefik/traefik --namespace traefik --create-namespace --values traefik.yaml
}

k3d cluster create cluster1 \
  --port 80:80@loadbalancer \
  --port 443:443@loadbalancer \
  --port 8000:8000@loadbalancer \
  --k3s-arg "--disable=traefik@server:0" \
  --k3s-arg "--tls-san=k3d-cluster1-server-0@server:*" \
  --network k3d-mesh
install_basic cluster1

if [ "$CLUSTER_COUNT" -ge "2" ]; then
  k3d cluster create cluster2 \
    --port 9080:80@loadbalancer \
    --port 9443:443@loadbalancer \
    --port 9000:8000@loadbalancer \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--tls-san=k3d-cluster2-server-0@server:*" \
    --network k3d-mesh
  install_basic cluster2
fi

if [ "$CLUSTER_COUNT" -eq "3" ]; then
  k3d cluster create cluster3 \
    --port 7080:80@loadbalancer \
    --port 7443:443@loadbalancer \
    --port 7000:8000@loadbalancer \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--tls-san=k3d-cluster3-server-0@server:*" \
    --network k3d-mesh

  install_basic cluster3
fi

