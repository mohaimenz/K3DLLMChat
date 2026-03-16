FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastapi==0.109.0 \
    uvicorn==0.27.0 \
    transformers==4.40.0 \
    pydantic==2.6.0 && \
    pip install --no-cache-dir torch==2.1.1 --index-url https://download.pytorch.org/whl/cpu

COPY inference_server.py /app/inference_server.py

EXPOSE 8001

CMD ["python", "/app/inference_server.py"]
