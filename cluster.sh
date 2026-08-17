#!/usr/bin/env bash

createCluster() {
  if ! k3d cluster get "$1" > /dev/null 2>&1; then
    if [ "$2" != "" ]; then
      MOUNT_VOLUME=(--volume "$2:/tmp/local-git-repo@server:*")
    fi

    k3d cluster create "$1"  \
      -e "http_proxy=$http_proxy@all" -e "HTTP_PROXY=$HTTP_PROXY@all" -e "no_proxy=$no_proxy@all" \
      -e "NO_PROXY=$NO_PROXY@all" -e "https_proxy=$http_proxy@all" -e "HTTPS_PROXY=$HTTP_PROXY@all" \
      --k3s-arg "--disable=traefik@server:0" \
      --network k3d-mesh \
      "${MOUNT_VOLUME[@]}" \
      --k3s-arg "--tls-san=k3d-$1-serverlb"@server:*
  else
    echo "Cluster $1 already exists"
  fi

  kubeconfigDir=$(find . -name "clusters" -print -quit)
    kubeconfigFile="$kubeconfigDir/kubeconfig/$1.yaml"
  echo "dropping kubeconfig to $kubeconfigFile"
  mkdir -p "$kubeconfigDir/kubeconfig/"
  k3d kubeconfig get "$1" > "$kubeconfigFile"
  sed -Ei "s/0.0.0.0:[0-9]+/k3d-$1-serverlb:6443/" "$kubeconfigFile"
}