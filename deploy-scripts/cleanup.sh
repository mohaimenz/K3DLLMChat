#!/usr/bin/env bash
set -euo pipefail

echo "===== CLEANING K3D + DOCKER ====="

echo "Removing k3d clusters..."
k3d cluster delete --all 2>/dev/null || true

echo "Removing k3d registries..."
k3d registry delete --all 2>/dev/null || true

echo "Removing all containers..."
docker ps -aq | xargs -r docker rm -f || true

echo "Removing project images..."
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' \
  | awk '/^llm-mvp-registry:5000\// {print $2}' \
  | sort -u \
  | xargs -r docker rmi -f || true

echo "Removing docker buildx builders..."
docker buildx ls --format '{{.Name}}' 2>/dev/null \
  | awk 'NF' \
  | sort -u \
  | xargs -r -n 1 docker buildx rm -f || true

echo "Removing project/k3d volumes by name..."
docker volume ls --format '{{.Name}}' \
  | awk '/^(k3d-|buildx_buildkit_|llm-mvp|local-path)/ {print $1}' \
  | sort -u \
  | xargs -r -n 1 docker volume rm -f || true

echo "Pruning builder cache..."
docker builder prune -a -f || true

echo "Pruning unused images..."
docker image prune -a -f || true

echo "Pruning unused volumes..."
docker volume prune -f || true

echo "Final docker cleanup..."
docker system prune -a --volumes -f || true

echo "===== CLEANUP COMPLETE ====="
docker system df
echo
docker volume ls || true