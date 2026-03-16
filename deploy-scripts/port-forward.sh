#!/bin/bash

NAMESPACE="llm-sidecar"

echo "Setting up port forwards..."
echo ""
echo "Frontend: http://localhost:3000"
echo "FastAPI:  http://localhost:8000"
echo ""
echo "Press Ctrl+C to stop port forwarding"
echo ""

# Kill any existing port-forward processes from previous runs
pkill -f "kubectl port-forward.*frontend-service" 2>/dev/null || true
pkill -f "kubectl port-forward.*fastapi-service" 2>/dev/null || true

# Start port forwards in background
kubectl port-forward -n ${NAMESPACE} service/frontend-service 3000:80 &
kubectl port-forward -n ${NAMESPACE} service/fastapi-service 8000:8000 &

# Wait for both processes
wait
