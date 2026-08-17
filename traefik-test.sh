#!/usr/bin/env bash

kubectl label --context=k3d-cluster1 namespace traefik istio.io/dataplane-mode=ambient
kubectl create --context=k3d-cluster1 namespace whoami
kubectl --context k3d-cluster1 create sa whoami -n whoami
kubectl label --context=k3d-cluster1 namespace whoami istio.io/dataplane-mode=ambient
kubectl apply --context=k3d-cluster1 -f samples/routing-cluster1.yaml

kubectl label --context=k3d-cluster2 namespace traefik istio.io/dataplane-mode=ambient
kubectl create --context=k3d-cluster2 namespace whoami
kubectl --context k3d-cluster2 create sa whoami -n whoami
kubectl label --context=k3d-cluster2 namespace whoami istio.io/dataplane-mode=ambient
kubectl apply --context=k3d-cluster2 -f samples/routing-cluster2.yaml
