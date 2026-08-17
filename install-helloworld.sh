#!/usr/bin/env bash

if [ "$CLUSTER_COUNT" == "" ]; then
  CLUSTER_COUNT="${1:-2}"
fi

if [ "$CLUSTER_COUNT" -gt "3" ]; then
  echo "A maximum cluster count of 3 is allowed"
  exit 1
fi

install_helloworld() {
  cluster="cluster$1"
  context="k3d-$cluster"

  kubectl create --context="${context}" namespace sample
  kubectl label --context="${context}" namespace sample istio.io/dataplane-mode=ambient
  kubectl apply --context="${context}" -f "samples/helloworld/helloworld-${cluster}.yaml" -n sample

  kubectl apply --context="${context}" -f samples/curl/curl.yaml -n sample

  istioctl --context "${context}" waypoint apply --name waypoint --for service -n sample --wait
  kubectl --context "${context}" label svc helloworld -n sample istio.io/use-waypoint=waypoint
  kubectl --context "${context}" label svc waypoint -n sample istio.io/global=true
}

install_helloworld "1"
if [ "$CLUSTER_COUNT" -ge "2" ]; then
  install_helloworld "2"
fi

if [ "$CLUSTER_COUNT" -eq "3" ]; then
  install_helloworld "3"
fi

kubectl apply --context="k3d-cluster1" -f samples/traefik/helloworld.yaml -n sample
