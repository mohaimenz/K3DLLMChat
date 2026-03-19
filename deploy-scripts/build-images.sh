#!/bin/bash
set -e

# Build images locally for k3d
IMAGE_PREFIX="k3d-llm-sidecar"
CLUSTER="k3d-llm-sidecar-cluster"

echo "Building Docker images for k3d..."

# Build model downloader
echo "Building downloader image..."
docker build -t ${IMAGE_PREFIX}/model-downloader:latest \
  -f inference/downloader/Dockerfile \
  inference/downloader/

# Build inference container
echo "Building inference image..."
docker build -t ${IMAGE_PREFIX}/inference:latest \
  -f inference/Dockerfile \
  inference/

# Build FastAPI sidecar
echo "Building fastapi image..."
docker build -t ${IMAGE_PREFIX}/fastapi-api:latest \
  -f api/Dockerfile \
  api/

# Build frontend
echo "Building frontend image..."
docker build -t ${IMAGE_PREFIX}/frontend:latest \
  -f frontend/Dockerfile \
  frontend/

echo "Loading images into k3d cluster..."
k3d image import ${IMAGE_PREFIX}/model-downloader:latest -c ${CLUSTER}
k3d image import ${IMAGE_PREFIX}/inference:latest -c ${CLUSTER}
k3d image import ${IMAGE_PREFIX}/fastapi-api:latest -c ${CLUSTER}
k3d image import ${IMAGE_PREFIX}/frontend:latest -c ${CLUSTER}

echo "All images built and loaded successfully"
