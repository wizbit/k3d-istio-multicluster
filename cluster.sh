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
}

createClusterWithHostPorts() {
  name=$1
  volume=$2
  port80=$3
  port443=$4
  port8000=$5

  if ! k3d cluster get "$name" > /dev/null 2>&1; then
    if [ "$2" != "" ]; then
      MOUNT_VOLUME=(--volume "$volume:/tmp/local-git-repo@server:*")
    fi

    k3d cluster create "$name"  \
      -e "http_proxy=$http_proxy@all" -e "HTTP_PROXY=$HTTP_PROXY@all" -e "no_proxy=$no_proxy@all" \
      -e "NO_PROXY=$NO_PROXY@all" -e "https_proxy=$http_proxy@all" -e "HTTPS_PROXY=$HTTP_PROXY@all" \
      --k3s-arg "--disable=traefik@server:0" \
      --port "$port80:80@loadbalancer" \
      --port "$port443:443@loadbalancer" \
      --port "$port8000:8000@loadbalancer" \
      --network k3d-mesh \
      "${MOUNT_VOLUME[@]}" \
      --k3s-arg "--tls-san=k3d-$name-serverlb"@server:*
  else
    echo "Cluster $name already exists"
  fi
}