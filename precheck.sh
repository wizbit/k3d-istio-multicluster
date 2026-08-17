#!/usr/bin/env bash

precheck() {
    which docker > /dev/null || { echo "docker not installed or not on path"; exit; }
    which kubectl > /dev/null || { echo "kubectl not installed or not on path"; exit; }
    which argocd > /dev/null || { echo "argocd not installed or not on path"; exit; }
    which k3d > /dev/null || { echo "k3d not installed or not on path"; exit; }
    kc=$(kubectl config current-context)
    safe=$(echo "$kc" | grep -E -v "docker-desktop|minikube|rancher-desktop|k3d-*|kind-*" || true)
    if [ -n "$safe" ]
    then
      echo "You are using kube-context $safe which doesn't look like a local cluster"
      exit 1
    fi
    echo "precheck passed"
}
