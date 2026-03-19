# Local LLM Serving on k3d using Transformers (CPU) + FastAPI Sidecar + React Frontend

This document defines the MVP implementation for a **local AI inference system running inside a k3d Kubernetes cluster**.

The goal is to learn:

- Kubernetes deployment patterns
- Sidecar architecture
- Local model serving
- Persistent model caching
- API orchestration

The system runs **entirely locally** on a MacBook using **k3d Kubernetes**.

---

# 1. Project Objective

Build a minimal end-to-end system running inside a **k3d Kubernetes cluster**.

Architecture:

```

Browser → React → FastAPI → Transformers Inference Container → Model → Response

```

The project demonstrates:

- Kubernetes deployments
- Sidecar container patterns
- Local LLM inference on CPU
- Persistent storage for models
- Simple frontend + backend communication

---

# 2. Architecture Overview

```

Browser
|
v
Frontend Service (React)
|
v
FastAPI Service
|
v
Pod (Sidecar Pattern)
├── Inference container (Transformers CPU inference)
└── FastAPI container
|
v
Persistent Volume (/models)

```

Everything runs locally using **k3d Kubernetes**.

---

# 3. Inference Engine

Inference is performed using a **Transformers-based CPU inference server**.

Implementation:

- Python container
- Hugging Face `transformers`
- `AutoModelForCausalLM`
- CPU inference only

The inference container exposes an **OpenAI-compatible API** so that the FastAPI sidecar can communicate with it using a standard interface.

---

# 4. Model Selection

## Primary Model

```

Qwen/Qwen2.5-0.5B-Instruct

```

Characteristics:

- Small instruction-tuned model
- Suitable for CPU inference
- Good for question answering and chat
- Public Hugging Face repository

---

# 5. Model Format

Models use **Hugging Face Transformers format**:

- SafeTensors / PyTorch weights
- Compatible with `transformers`

---

# 6. Model Size Expectations

Approximate storage:

```

Model size: ~1–1.5 GB
Cache overhead: ~1–2 GB

```

PVC requirement:

```

10Gi

```

The PVC is intentionally oversized to allow model cache overhead and iteration without resizing storage.

---

# 7. Model Download Strategy

## InitContainer

Model download is performed using a Kubernetes **initContainer**.

Implementation:

- Python container
- `huggingface_hub`
- `snapshot_download()`

Download location:

```

/models/hf

```

Environment variables:

```

HF_HOME=/models/hf
TRANSFORMERS_CACHE=/models/hf
HUGGINGFACE_HUB_CACHE=/models/hf

```

Behavior:

- Checks if the model exists
- Downloads only if missing
- Exits before inference container starts

If download fails:

- initContainer fails
- pod restart is handled automatically by Kubernetes

---

# 8. Persistent Storage

PVC mount path:

```

/models

```

Storage class:

```

local-path

````

Purpose:

- Cache model files
- Avoid repeated downloads
- Speed up pod restarts

## PVC Lifecycle

| Action | Result |
|------|-------|
| Pod restart | Model cache retained |
| Deployment update | Model cache retained |
| Cluster deletion | PVC and cached model removed |

Model cache is therefore **ephemeral across cluster recreation**, which is acceptable for this MVP.

---

# 9. API Design

## FastAPI Public Endpoints

### POST `/generate`

Request

```json
{
  "prompt": "string"
}
````

Response

```json
{
  "text": "generated response"
}
```

---

### GET `/health`

```json
{
  "status": "ok"
}
```

---

# 10. FastAPI → Inference Communication

FastAPI calls the inference container using an OpenAI-compatible endpoint:

```
POST /v1/chat/completions
```

Example request:

```json
{
  "model": "MODEL_ID",
  "messages": [
    {"role": "system", "content": "SYSTEM_MESSAGE"},
    {"role": "user", "content": "Explain Kubernetes"}
  ],
  "max_tokens": 256,
  "temperature": 0.7,
  "top_p": 0.9
}
```

Example response:

```json
{
  "id": "chatcmpl-local",
  "object": "chat.completion",
  "created": 0,
  "model": "MODEL_ID",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "generated response"
      },
      "finish_reason": "stop"
    }
  ]
}
```

---

# 11. Model Selection Configuration

Model used for inference is controlled via environment variable:

```
MODEL_ID
```

Example:

```
Qwen/Qwen2.5-0.5B-Instruct
```

This value is injected via a **ConfigMap** and passed to:

* downloader container
* inference container
* FastAPI sidecar

Changing the model requires:

1. Update ConfigMap
2. Redeploy pod

Container images **do not need to be rebuilt**.

---

# 12. System Message Configuration

Default system message:

```
You are a helpful assistant. Answer clearly and directly. If unsure, say so.
```

Configured via environment variable.

---

# 13. Generation Defaults

| Parameter   | Value |
| ----------- | ----- |
| max_tokens  | 256   |
| temperature | 0.7   |
| top_p       | 0.9   |

Streaming responses are not required.

---

# 14. Timeout Behavior

FastAPI → inference timeout:

```
120 seconds
```

---

# 15. Error Handling

| Scenario            | Behavior |
| ------------------- | -------- |
| Model loading       | HTTP 503 |
| Inference error     | HTTP 500 |
| Invalid input       | HTTP 400 |
| Unexpected response | HTTP 502 |

Frontend displays error messages directly.

---

# 16. Pod Architecture

Backend deployment contains **two containers**.

### Container 1 — Inference Container

Responsibilities:

* Load the model
* Run CPU inference
* Provide OpenAI-compatible inference API

Internal port:

```
8001
```

---

### Container 2 — FastAPI Sidecar

Responsibilities:

* Receive frontend requests
* Translate requests to inference API
* Normalize responses

Internal port:

```
8000
```

Shared resources:

* Persistent volume `/models`
* localhost networking

---

# 17. Frontend Design

React frontend provides:

* Prompt input field
* Submit button
* Response display
* Loading state
* Error state

---

# 18. Frontend Service

Frontend service port:

```
80
```

Access via:

```
kubectl port-forward
```

Forwarded ports:

| Local | Service              |
| ----- | -------------------- |
| 3000  | frontend-service:80  |
| 8000  | fastapi-service:8000 |

Port forwarding is automated using:

```
scripts/port-forward.sh
```

---

# 19. Resource Strategy

Resource **requests** are defined.

Strict **limits are avoided** to prevent premature OOM during experimentation.

---

# 20. Performance Expectations

CPU inference latency may range between:

```
5–30 seconds per request
```

This is acceptable for the learning environment.

---

# 21. Kubernetes Deployment Strategy

Manifests are written as **plain Kubernetes YAML files**.

No Helm or Kustomize.

Deployment workflow uses scripts:

```
scripts/create-cluster.sh
scripts/build-images.sh
scripts/deploy.sh
scripts/port-forward.sh
```

## Script Execution Order

Typical development workflow:

```bash
./scripts/cleanup.sh
./scripts/create-cluster.sh
./scripts/build-images.sh
./scripts/deploy.sh
./scripts/port-forward.sh
```

Scripts remain separate to simplify debugging.

---

# 22. Container Image Strategy

Images are built locally for Apple Silicon.

Architecture:

```
linux/arm64
```

Images are pushed to a **local k3d registry**.

Host push target:

```
127.0.0.1:5001
```

Cluster registry address:

```
llm-mvp-registry:5000
```

## Registry Port Translation

| Context            | Address               |
| ------------------ | --------------------- |
| Host machine       | 127.0.0.1:5001        |
| Kubernetes cluster | llm-mvp-registry:5000 |

Docker pushes images to `127.0.0.1:5001`.

Cluster nodes pull images from `llm-mvp-registry:5000`.

---

# 23. Logging and Debugging

Logs are written to container stdout/stderr.

Debugging commands:

```bash
kubectl get pods -n llm-sidecar
kubectl describe pod -n llm-sidecar -l app=inference-api
kubectl logs -n llm-sidecar -l app=inference-api -c inference
kubectl logs -n llm-sidecar -l app=inference-api -c fastapi-sidecar
kubectl get pvc -n llm-sidecar
kubectl get services -n llm-sidecar
```

---

# 24. CORS Configuration

Frontend and API run on different ports:

| Service  | Address        |
| -------- | -------------- |
| Frontend | localhost:3000 |
| API      | localhost:8000 |

Browsers treat this as **cross-origin**.

Therefore FastAPI enables **CORS headers** allowing requests from the frontend origin.

---

# 25. Acceptance Criteria

System is successful when:

* Model downloads automatically
* Model persists after restart
* `/generate` returns output
* `/health` returns OK
* Frontend communicates with backend
* Port-forward works reliably
* System deploys with a single command

---

# 26. Out of Scope

The following are not included:

* streaming responses
* authentication
* autoscaling
* observability stack
* production deployment
* Helm charts

---

# 27. Definition of Done

Project is complete when:

* Kubernetes manifests deploy successfully
* Model serving works end-to-end
* Persistent model storage verified
* FastAPI API functional
* React frontend integrated
* Full system works through port-forward

---

# 28. System Dependencies

Minimum environment requirements:

| Component  | Requirement          |
| ---------- | -------------------- |
| Hardware   | Apple Silicon Mac    |
| OS         | macOS 14+            |
| Docker     | Docker Desktop 4.30+ |
| Kubernetes | k3d 5.6+             |
| kubectl    | 1.29+                |
| Node.js    | 18+                  |
| Python     | 3.11+                |

Required CLI tools:

```
docker
docker buildx
k3d
kubectl
bash
curl
```
