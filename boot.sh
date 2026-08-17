#!/usr/bin/env bash

CLUSTER_COUNT="${1:-1}"

if [ "$CLUSTER_COUNT" -gt "3" ]; then
  echo "A maximum cluster count of 3 is allowed"
  exit 1
fi

./install-clusters.sh "$CLUSTER_COUNT"
./install-istio.sh "$CLUSTER_COUNT"