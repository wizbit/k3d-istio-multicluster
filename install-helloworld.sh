#!/usr/bin/env bash

ISTIO_TYPE="$1"

CTX_CLUSTER1="k3d-cluster1"
CTX_CLUSTER2="k3d-cluster2"

install_ambient() {
    kubectl create --context="${CTX_CLUSTER1}" namespace sample
    kubectl create --context="${CTX_CLUSTER2}" namespace sample

  kubectl label --context="${CTX_CLUSTER1}" namespace sample istio.io/dataplane-mode=ambient
  kubectl label --context="${CTX_CLUSTER2}" namespace sample istio.io/dataplane-mode=ambient

  kubectl apply --context="${CTX_CLUSTER1}" -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample
  kubectl apply --context="${CTX_CLUSTER2}" -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample

#  kubectl apply --context="${CTX_CLUSTER1}" -f samples/helloworld/helloworld.yaml -l version=v1 -n sample
  kubectl apply --context="${CTX_CLUSTER2}" -f samples/helloworld/helloworld.yaml -l version=v2 -n sample

  kubectl apply --context="${CTX_CLUSTER1}" -f samples/curl/curl.yaml -n sample
  kubectl apply --context="${CTX_CLUSTER2}" -f samples/curl/curl.yaml -n sample

  kubectl apply --context="${CTX_CLUSTER1}" -f samples/traefik/helloworld.yaml -n sample
}


install_sidecar() {
  kubectl create --context="${CTX_CLUSTER1}" namespace sample
  kubectl create --context="${CTX_CLUSTER2}" namespace sample

  kubectl label --context="${CTX_CLUSTER1}" namespace sample istio-injection=enabled
  kubectl label --context="${CTX_CLUSTER2}" namespace sample istio-injection=enabled

  kubectl apply --context="${CTX_CLUSTER1}" -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample
  kubectl apply --context="${CTX_CLUSTER2}" -f samples/helloworld/helloworld.yaml -l service=helloworld -n sample

  kubectl apply --context="${CTX_CLUSTER1}" -f samples/helloworld/helloworld.yaml -l version=v1 -n sample
  kubectl apply --context="${CTX_CLUSTER2}" -f samples/helloworld/helloworld.yaml -l version=v2 -n sample

  kubectl apply --context="${CTX_CLUSTER1}" -f samples/curl/curl.yaml -n sample
  kubectl apply --context="${CTX_CLUSTER2}" -f samples/curl/curl.yaml -n sample

  sleep 10
  kubectl exec --context="${CTX_CLUSTER1}" -n sample -c curl \
      "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
      app=curl -o jsonpath='{.items[0].metadata.name}')" \
      -- curl -sS helloworld.sample:5000/hello
}

if [ "$ISTIO_TYPE" == "ambient" ]; then
  install_ambient
elif [ "$ISTIO_TYPE" == "sidecar" ]; then
  install_sidecar
else
  printf "You must specify ambient or sidecar"
  exit 1
fi
