#!/usr/bin/env bash

ISTIO_TYPE="$1"

if [ "$ISTIO_TYPE" != "ambient" ] && [ "$ISTIO_TYPE" != "sidecar" ]; then
  printf "You must specify ambient or sidecar"
  exit 1
fi

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

prelim_istio() {
  make -f ./Makefile.selfsigned.mk root-ca
  make -f ./Makefile.selfsigned.mk cluster1-cacerts
  make -f ./Makefile.selfsigned.mk cluster2-cacerts
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
}

install_istio_sidecar() {
  cluster=$1
  context="k3d-$cluster"
  network=$2

  kubectl label --context="${context}" namespace traefik istio-injection=enabled

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
  values:
    global:
      platform: k3d
      meshID: mesh1
      multiCluster:
        clusterName: ${cluster}
      network: ${network}
EOF

  gen-eastwest-gateway.sh --network "${network}" | istioctl install --context="${context}" -y -f -
  kubectl --context="${context}" apply -n istio-system -f ./expose-services.yaml
}

prelim_istio

if [ "$ISTIO_TYPE" == "ambient" ]; then
  install_istio_ambient cluster1 network1
  install_istio_ambient cluster2 network2
else
  install_istio_sidecar cluster1 network1
  install_istio_sidecar cluster2 network2

  kubectl --context="k3d-cluster1" apply -n istio-system -f ./expose-services.yaml
  kubectl --context="k3d-cluster2" apply -n istio-system -f ./expose-services.yaml
fi

cluster1IP=$(docker inspect k3d-cluster1-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')
cluster2IP=$(docker inspect k3d-cluster2-server-0 | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')

for cluster in cluster1 cluster2; do
  context="k3d-${cluster}"
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
done

istioctl create-remote-secret \
  --context="k3d-cluster1" \
  --name=cluster1 \
  --server="https://${cluster1IP}:6443" | \
  kubectl apply -f - --context="k3d-cluster2"

istioctl create-remote-secret \
  --context="k3d-cluster2" \
  --name=cluster2 \
  --server="https://${cluster2IP}:6443" | \
  kubectl apply -f - --context="k3d-cluster1"

istioctl remote-clusters --context="k3d-cluster1"