FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastapi==0.109.0 \
    uvicorn==0.27.0 \
    httpx==0.25.2 \
    pydantic==2.6.0

COPY main.py /app/main.py

EXPOSE 8000

CMD ["python", "/app/main.py"]
