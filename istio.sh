#!/usr/bin/env bash

initializeIstio() {
  helm repo add istio https://istio-release.storage.googleapis.com/charts
  helm repo update

  make -f ./Makefile.selfsigned.mk root-ca
}

installIstio() {
  cluster=$1
  context="k3d-$cluster"
  network=$2

  # Istio requires the Gateway API CRDs
  kubectl apply --context "${context}" -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml


  make -f ./Makefile.selfsigned.mk $cluster-cacerts

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

connectIstioClusters() {
  clusterCount=$1

  for ((i = 1 ; i <= "$clusterCount" ; i++ )); do
    clusterIP=$(docker inspect "k3d-cluster$i-server-0" | jq -r '.[0].NetworkSettings.Networks."k3d-mesh".IPAddress')

    for ((j = 1 ; j <= "$clusterCount" ; j++ )); do
      if [ $i != $j ]; then
          istioctl create-remote-secret \
            --context="k3d-cluster$i" \
            --name=cluster$i \
            --server="https://${clusterIP}:6443" | \
            kubectl apply -f - --context="k3d-cluster$j"
      fi
    done
  done
}

connectIstioCheck() {
  for ((i = 1 ; i <= "$clusterCount" ; i++ )); do
    echo "Cluster $i check"
    istioctl remote-clusters --context="k3d-cluster1"
  done
}