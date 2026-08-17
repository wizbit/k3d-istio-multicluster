#!/usr/bin/env bash

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

prelim_istio() {
  make -f ./Makefile.selfsigned.mk root-ca
  make -f ./Makefile.selfsigned.mk cluster1-cacerts
  make -f ./Makefile.selfsigned.mk cluster2-cacerts
}

install_istio() {
  cluster=$1
  context="k3d-$cluster"
  network=$2

  kubectl create --context "${context}" namespace istio-system
  kubectl label --context "${context}" namespace istio-system "topology.istio.io/network=${network}"

  kubectl create --context "${context}" secret generic cacerts -n istio-system --save-config --dry-run=client \
        --from-file="${cluster}/ca-cert.pem" \
        --from-file="${cluster}/ca-key.pem" \
        --from-file="${cluster}/root-cert.pem" \
        --from-file="${cluster}/cert-chain.pem" \
        -o yaml | \
        kubectl apply -f -

  helm upgrade --install istio-base istio/base -n istio-system --kube-context "${context}" --wait
  helm upgrade --install istiod istio/istiod -n istio-system --kube-context "${context}" --set global.meshID=mesh1 --set global.multiCluster.clusterName="${cluster}" --set global.network="${network}" --set profile=ambient --set env.AMBIENT_ENABLE_MULTI_NETWORK="true" --set env.AMBIENT_ENABLE_BAGGAGE="true" --wait
  helm upgrade --install istio-cni istio/cni -n istio-system --kube-context "${context}" --set profile=ambient --set global.platform=k3d --wait

  helm upgrade --install ztunnel istio/ztunnel -n istio-system --kube-context "${context}" --set multiCluster.clusterName="${cluster}" --set global.network="${network}" --wait

  ./gen-eastwest-gateway.sh \
    --network "${network}" \
    --ambient | \
    kubectl --context="${context}" apply -f -
}

prelim_istio

install_istio cluster1 network1
install_istio cluster2 network2

cluster1IP=$(docker inspect k3d-cluster1-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')
cluster2IP=$(docker inspect k3d-cluster2-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')

istioctl create-remote-secret \
  --context="k3d-cluster1" \
  --name=cluster1 \
  --server="http://${cluster1IP}:6443" | \
  kubectl apply -f - --context="k3d-cluster2"

istioctl create-remote-secret \
  --context="k3d-cluster2" \
  --name=cluster2 \
  --server="http://${cluster2IP}:6443" | \
  kubectl apply -f - --context="k3d-cluster1"