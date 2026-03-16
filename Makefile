.PHONY: help cleanup create-cluster build-images deploy port-forward full-deploy logs shell

help:
	@echo "k3d LLM MVP - Available commands:"
	@echo ""
	@echo "  make full-deploy    - Complete setup: cleanup → create → build → deploy → port-forward"
	@echo "  make cleanup        - Delete k3d cluster"
	@echo "  make create-cluster - Create k3d cluster with local registry"
	@echo "  make build-images   - Build and push Docker images"
	@echo "  make deploy         - Deploy Kubernetes manifests"
	@echo "  make port-forward   - Setup port forwarding"
	@echo ""
	@echo "  make logs-inference - View inference container logs"
	@echo "  make logs-fastapi   - View FastAPI sidecar logs"
	@echo "  make logs-frontend  - View frontend container logs"
	@echo "  make logs-downloader- View model downloader logs"
	@echo ""
	@echo "  make status         - Show pod and service status"
	@echo "  make shell-backend  - Shell into backend pod"
	@echo "  make shell-frontend - Shell into frontend pod"
	@echo ""

full-deploy: cleanup create-cluster build-images deploy port-forward

cleanup:
	@echo "Running cleanup..."
	@./deploy-scripts/cleanup.sh

create-cluster:
	@echo "Creating cluster..."
	@./deploy-scripts/create-cluster.sh

build-images:
	@echo "Building images..."
	@./deploy-scripts/build-images.sh

deploy:
	@echo "Deploying manifests..."
	@./deploy-scripts/deploy.sh

port-forward:
	@echo "Setting up port forwarding..."
	@./deploy-scripts/port-forward.sh

logs-inference:
	@kubectl logs -n llm-sidecar -f -l app=inference-api -c inference

logs-fastapi:
	@kubectl logs -n llm-sidecar -f -l app=inference-api -c fastapi-sidecar

logs-frontend:
	@kubectl logs -n llm-sidecar -f -l app=frontend

logs-downloader:
	@kubectl logs -n llm-sidecar -l app=inference-api -c model-downloader --previous

status:
	@echo "Cluster status:"
	@kubectl get nodes
	@echo ""
	@echo "Pod status:"
	@kubectl get pods -n llm-sidecar -o wide
	@echo ""
	@echo "Services:"
	@kubectl get services -n llm-sidecar
	@echo ""
	@echo "PVCs:"
	@kubectl get pvc -n llm-sidecar

shell-backend:
	@kubectl exec -it -n llm-sidecar -l app=inference-api -c fastapi-sidecar -- /bin/bash || kubectl exec -it -n llm-sidecar -l app=inference-api -c fastapi-sidecar -- /bin/sh

shell-frontend:
	@kubectl exec -it -n llm-sidecar -l app=frontend -- /bin/bash || kubectl exec -it -n llm-sidecar -l app=frontend -- /bin/sh
