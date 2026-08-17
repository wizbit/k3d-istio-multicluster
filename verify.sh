#!/usr/bin/env bash

istioctl remote-clusters --context=k3d-cluster1

if [ "sample" == "$1" ]; then
  kubectl create --context=k3d-cluster1 namespace sample
  kubectl label --context=k3d-cluster1 namespace sample istio.io/dataplane-mode=ambient
  kubectl apply --context=k3d-cluster1 -f samples/helloworld.yaml -l service=helloworld -n sample
  kubectl label --context=k3d-cluster1 svc helloworld -n sample istio.io/global="true"
  kubectl apply --context=k3d-cluster1 -f samples/helloworld.yaml -l version=v1 -n sample

  kubectl create --context=k3d-cluster2 namespace sample
  kubectl label --context=k3d-cluster2 namespace sample istio.io/dataplane-mode=ambient
  kubectl apply --context=k3d-cluster2 -f samples/helloworld.yaml -l service=helloworld -n sample
  kubectl label --context=k3d-cluster2 svc helloworld -n sample istio.io/global="true"
  kubectl apply --context=k3d-cluster2 -f samples/helloworld.yaml -l version=v2 -n sample

  # Add curl
  kubectl apply --context=k3d-cluster1 -f curl.yaml -n sample
  kubectl apply --context=k3d-cluster2 -f curl.yaml -n sample

  kubectl exec --context="k3d-cluster1" -n sample -c curl \
      "$(kubectl get pod --context="k3d-cluster1" -n sample -l \
      app=curl -o jsonpath='{.items[0].metadata.name}')" \
      -- curl -sS helloworld.sample:5000/hello
fi