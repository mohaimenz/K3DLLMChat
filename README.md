# k3d LLM Inference Pod

A minimal end-to-end local AI inference system running inside a k3d Kubernetes cluster on Apple Silicon.

**Stack:**
- Kubernetes: k3d (local)
- Backend: Python FastAPI + Transformers
- Frontend: React with Vite
- Model: Qwen 2.5 0.5B (Instruct tuning)
- Storage: Persistent Volume (10Gi)

---

## Quick Start

### Setup and Deploy

```bash
# Make scripts executable
chmod +x deploy-scripts/*.sh

# Clean up any existing cluster
./deploy-scripts/cleanup.sh

# Create k3d cluster with local registry
./deploy-scripts/create-cluster.sh

# Build and push Docker images
./deploy-scripts/build-images.sh

# Deploy Kubernetes manifests
./deploy-scripts/deploy.sh

# Start port forwarding
./deploy-scripts/port-forward.sh
```

### Access

- **Frontend**: http://localhost:3000
- **API Health**: http://localhost:8000/health
- **API Docs**: http://localhost:8000/docs

---

## Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ http://localhost:3000
       ▼
┌───────────────────────┐
│  React Frontend       │
└──────┬────────────────┘
       │ http://localhost:8000
       ▼
┌──────────────────────────────┐
│ FastAPI Sidecar (8000)       │
├──────────────────────────────┤
│ Inference Pod                │
│ ├─ Inference Server (8001)   │
│ └─ Model Cache (/models)     │
└──────┬───────────────────────┘
       │
       ▼
    Persistent Volume Claim (10Gi)
```

## Configuration

Edit environment variables in `k8s/configmap.yaml`:

```yaml
MODEL_ID: "Qwen/Qwen2.5-0.5B-Instruct"  # HuggingFace model
SYSTEM_MESSAGE: "You are a helpful assistant..."
INFERENCE_HOST: "localhost"
INFERENCE_PORT: "8001"
```

Change the model, then redeploy:
```bash
kubectl apply -f k8s/configmap.yaml -n llm-sidecar
kubectl rollout restart deployment/inference-api -n llm-sidecar
```

Change generation parameters in `inference/inference_server.py` and rebuilding:
```bash
./deploy-scripts/build-images.sh
kubectl rollout restart deployment/inference-api -n llm-sidecar
```

---

## Ports

| Local | Service           | Purpose |
|-------|-------------------|---------|
| 3000  | frontend-service  | React UI |
| 8000  | fastapi-service   | Public API |
| 8001  | (internal)        | Inference server |

---

## Debugging

### Check cluster status

```bash
kubectl get nodes
kubectl get pods -n llm-sidecar
kubectl get services -n llm-sidecar
kubectl get pvc -n llm-sidecar
```

### View logs

```bash
# FastAPI sidecar
kubectl logs -n llm-sidecar -f -l app=inference-api -c fastapi-sidecar

# Inference container
kubectl logs -n llm-sidecar -f -l app=inference-api -c inference

# Model downloader (first start only)
kubectl logs -n llm-sidecar -l app=inference-api -c model-downloader --previous
```

### Describe a failing pod

```bash
kubectl describe pod -n llm-sidecar <pod-name>
```

### Direct API test

```bash
curl http://localhost:8000/health

curl -X POST http://localhost:8000/generate \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explain quantum computing in one sentence."}'
```

## Development

### Local frontend development

```bash
cd frontend
npm install
npm run dev
```

The dev server runs on `localhost:5173` and proxies to `http://localhost:8000`.

### Local backend testing

```bash
cd api
pip install fastapi uvicorn httpx pydantic
python main.py
```

## Cleanup

Delete the cluster and all associated resources:
```bash
./deploy-scripts/cleanup.sh
```

For details, see [prd.md](prd.md).