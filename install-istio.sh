#!/usr/bin/env bash

if [ "$CLUSTER_COUNT" == "" ]; then
  CLUSTER_COUNT="${1:-2}"
fi

if [ "$CLUSTER_COUNT" -gt "3" ]; then
  echo "A maximum cluster count of 3 is allowed"
  exit 1
fi

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

prelim_istio() {
  make -f ./Makefile.selfsigned.mk root-ca
  make -f ./Makefile.selfsigned.mk cluster1-cacerts
  make -f ./Makefile.selfsigned.mk cluster2-cacerts
  make -f ./Makefile.selfsigned.mk cluster3-cacerts
}

install_istio_ambient() {
  cluster=$1
  context="k3d-$cluster"
  network=$2

  kubectl label --context="${context}" namespace traefik istio.io/dataplane-mode=ambient


  kubectl create --context "${context}" namespace istio-system
  kubectl label --context "${context}" namespace istio-system "topology.istio.io/network=${network}"

  kubectl create --context "${context}" secret generic cacerts -n istio-system --dry-run=client \
        --from-file="${cluster}/ca-cert.pem" \
        --from-file="${cluster}/ca-key.pem" \
        --from-file="${cluster}/root-cert.pem" \
        --from-file="${cluster}/cert-chain.pem" \
        -o yaml | kubectl --context "${context}" apply -f -

  cat <<EOF | istioctl install --context="${context}" -y -f -
apiVersion: insall.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: ambient
  components:
    pilot:
      k8s:
        env:
          - name: AMBIENT_ENABLE_MULTI_NETWORK
            value: "true"
          - name: AMBIENT_ENABLE_BAGGAGE
            value: "true"
  values:
    global:
      platform: k3d
      meshID: mesh1
      multiCluster:
        clusterName: ${cluster}
      network: ${network}
EOF


cat <<EOF | kubectl apply --context="${context}" -f -
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: istio-eastwestgateway
  namespace: istio-system
  labels:
    topology.istio.io/network: "${network}"
spec:
  gatewayClassName: istio-east-west
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
    tls:
      mode: Terminate # represents double-HBONE
      options:
        gateway.istio.io/tls-terminate-mode: ISTIO_MUTUAL
EOF

  # Manually create a long-lived token secret for Istio
  kubectl apply --context "${context}" -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: istio-reader-service-account-token
  namespace: istio-system
  annotations:
    kubernetes.io/service-account.name: istio-reader-service-account
type: kubernetes.io/service-account-token
EOF
}

install

prelim_istio

install_istio_ambient cluster1 network1

if [ "$CLUSTER_COUNT" -ge "2" ]; then
  install_istio_ambient cluster2 network2
fi

if [ "$CLUSTER_COUNT" -eq "3" ]; then
  install_istio_ambient cluster3 network3
fi

cluster1IP=$(docker inspect k3d-cluster1-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')

if [ "$CLUSTER_COUNT" -ge "2" ]; then

  # Cluster 1 secret to other clusters
  istioctl create-remote-secret \
    --context="k3d-cluster1" \
    --name=cluster1 \
    --server="https://${cluster1IP}:6443" | \
    kubectl apply -f - --context="k3d-cluster2"

  if [ "$CLUSTER_COUNT" -eq "3" ]; then
    istioctl create-remote-secret \
      --context="k3d-cluster1" \
      --name=cluster1 \
      --server="https://${cluster1IP}:6443" | \
      kubectl apply -f - --context="k3d-cluster3"
  fi

  # Cluster 2 secret to other clusters
  cluster2IP=$(docker inspect k3d-cluster2-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')

  istioctl create-remote-secret \
    --context="k3d-cluster2" \
    --name=cluster2 \
    --server="https://${cluster2IP}:6443" | \
    kubectl apply -f - --context="k3d-cluster1"

  if [ "$CLUSTER_COUNT" -eq "3" ]; then
    istioctl create-remote-secret \
      --context="k3d-cluster2" \
      --name=cluster2 \
      --server="https://${cluster2IP}:6443" | \
      kubectl apply -f - --context="k3d-cluster3"

    cluster3IP=$(docker inspect k3d-cluster3-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')

    # Cluster 3 secret to other clusters
    istioctl create-remote-secret \
      --context="k3d-cluster3" \
      --name=cluster3 \
      --server="https://${cluster3IP}:6443" | \
      kubectl apply -f - --context="k3d-cluster1"

    istioctl create-remote-secret \
      --context="k3d-cluster3" \
      --name=cluster3 \
      --server="https://${cluster3IP}:6443" | \
      kubectl apply -f - --context="k3d-cluster2"
  fi

  sleep 10
  echo "Cluster 1 check"
  istioctl remote-clusters --context="k3d-cluster1"

  echo ""
  echo "Cluster 2 check"
  istioctl remote-clusters --context="k3d-cluster2"

  echo ""
  echo "Cluster 3 check"
  istioctl remote-clusters --context="k3d-cluster3"
fi