#!/usr/bin/env bash

kubectl create --context="k3d-cluster1" namespace argocd
kubectl apply --context="k3d-cluster1" -k argocd -n argocd --server-side --force-conflicts

echo "Waiting for ArgoCD"
kubectl wait --for create secret -n argocd argocd-initial-admin-secret

ADMIN_PASSWORD=$(kubectl get --context="k3d-cluster1" secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)
echo "login with at https://argocd.docker.localhost"
echo "username: admin"
echo "password: $ADMIN_PASSWORD"
echo ""
echo "Please change the password ASAP"