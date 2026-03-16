FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir \
    huggingface-hub==0.21.2 \
    transformers==4.36.2 && \
    pip install --no-cache-dir torch==2.1.1 --index-url https://download.pytorch.org/whl/cpu

COPY download_model.py /app/download_model.py

# Run the model downloader
CMD ["python", "/app/download_model.py"]
