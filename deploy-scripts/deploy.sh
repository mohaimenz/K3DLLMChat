#!/bin/bash
set -e

echo "Deploying Kubernetes manifests..."

NAMESPACE="k3d-llm-sidecar"

# Create namespace
echo "Creating namespace: ${NAMESPACE}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests in order
echo "Applying ConfigMap..."
kubectl apply -f k8s/configmap.yaml -n ${NAMESPACE}

echo "Applying PVC..."
kubectl apply -f k8s/pvc.yaml -n ${NAMESPACE}

echo "Applying Backend Deployment..."
kubectl apply -f k8s/deployment.yaml -n ${NAMESPACE}

echo "Applying Frontend Deployment..."
kubectl apply -f k8s/deployment-frontend.yaml -n ${NAMESPACE}

echo "Applying Services..."
kubectl apply -f k8s/service-fastapi.yaml -n ${NAMESPACE}
kubectl apply -f k8s/service-frontend.yaml -n ${NAMESPACE}

echo "Waiting for deployments to be ready..."
kubectl rollout status deployment/inference-api -n ${NAMESPACE} --timeout=300s
kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s

echo "Deployment complete"

echo "Pod status:"
kubectl get pods -n ${NAMESPACE}

echo "Services:"
kubectl get services -n ${NAMESPACE}
