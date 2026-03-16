#!/bin/bash
set -e

CLUSTER_NAME="llm-mvp"
AGENTS=1

if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
  echo "Cluster ${CLUSTER_NAME} already exists"
  exit 0
fi

echo "Creating k3d cluster: ${CLUSTER_NAME}"
k3d cluster create ${CLUSTER_NAME} \
  --agents ${AGENTS} \
  --port "3000:3000@loadbalancer" \
  --port "8000:8000@loadbalancer" \
  --wait

echo "Cluster ${CLUSTER_NAME} created successfully"
echo "Images will be loaded with: k3d image import ... -c ${CLUSTER_NAME}"
