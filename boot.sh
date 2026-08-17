#!/usr/bin/env bash

CLUSTER_COUNT="1"
VOLUME=""

while getopts "c:v:" option; do
  case $option in
    c) CLUSTER_COUNT=$OPTARG;;
    v) VOLUME=$OPTARG;;
    *) echo>&2 "error: only -c and -v allowed" && exit 1;;
  esac
done
shift "$((OPTIND-1))"

if [ "$1" != "" ]; then
  echo>&2 "error: only -c and -v allowed" && exit 1
fi

if [ "$CLUSTER_COUNT" -gt "3" ]; then
  echo "A maximum cluster count of 3 is allowed"
  exit 1
fi

source precheck.sh
source cluster.sh
source argocd.sh
source istio.sh

precheck
initializeIstio

for ((i = 1 ; i <= "$CLUSTER_COUNT" ; i++ )); do
  if [ "$i" == "1" ]; then
    createClusterWithHostPorts "cluster$i" "$VOLUME" 80 443 8000
  else
    createCluster "cluster$i" "$VOLUME"
  fi
  installIstio "cluster$i" "network$i"
done

kubectl config use-context k3d-cluster1

connectIstioClusters "$CLUSTER_COUNT"

deployArgoCD argocd 8080 "$VOLUME"
addClusters "$CLUSTER_COUNT"

connectIstioCheck "$CLUSTER_COUNT"

echo "Add System Project"
kubectl apply -f ./system/project.yaml
