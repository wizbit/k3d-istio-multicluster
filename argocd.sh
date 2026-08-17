#!/usr/bin/env bash

deployArgoCD() {
  ns="$1"
  port="$2"
  volume="$3"

  manifestDir=$(find . -name "argocd" -type d -print -quit)
  if [ "$volume" == "" ]; then
    manifestDir="$manifestDir/standard"
  else
    manifestDir="$manifestDir/local"
  fi

  kubectl create ns "$ns" || true
  kubectl apply -n "$ns" -k "$manifestDir" --server-side --force-conflicts

  echo awaiting argocd server + redis to startup
  kubectl wait -n "$ns" deploy/argocd-server --for condition=available --timeout=5m
  kubectl wait -n "$ns" deploy/argocd-redis  --for condition=available --timeout=5m

  echo port forwarding argocd server
  kubectl port-forward -n "$ns" deploy/argocd-server "$port":8080 >/dev/null 2>&1 &
  sleep 3

  # setup new password for argocd
  argo_host=localhost:${port}
  initial_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

  echo "Access the UI at: http://$argo_host with user: admin and password: $initial_password"
}

addClusters() {
  cluster_count=$1
  for ((i = 1 ; i <= "$cluster_count" ; i++ )); do
    cluster="cluster$i"

    kubectl create --context "k3d-$cluster" namespace argocd || echo "argocd namespace exists"
    kubectl create --context "k3d-$cluster" serviceaccount argocd-manager -n argocd

    kubectl create --context "k3d-$cluster" clusterrolebinding argocd-manager-role \
      --clusterrole=cluster-admin \
      --serviceaccount=argocd:argocd-manager

    cat << EOF | kubectl --context "k3d-$cluster" apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: argocd
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
EOF

    TOKEN=$(kubectl get --context "k3d-$cluster" secret argocd-manager-token -n argocd -o jsonpath='{.data.token}' | base64 -d)
    CADATA=$(kubectl config --context "k3d-$cluster" view --raw -o jsonpath="{.clusters[?(@.name==\"k3d-$cluster\")].cluster.certificate-authority-data}")

    cat << EOF | kubectl apply --context "k3d-cluster1" -f -
apiVersion: v1
kind: Secret
metadata:
  name: $cluster-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: $cluster
  # The magic trick: targeting the container name and the internal K3s port (6443)
  server: "https://k3d-$cluster-server-0:6443"
  config: |
    {
      "bearerToken": "${TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "$CADATA"
      }
    }
EOF
  done
}