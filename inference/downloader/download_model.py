import os
from huggingface_hub import snapshot_download

model_id = os.getenv("MODEL_ID")
hf_home = os.getenv("HF_HOME", "/models/hf")

print(f"Downloading model: {model_id}")
print(f"Cache location: {hf_home}")

try:
    # Check if model already exists
    cache_path = os.path.join(hf_home, "models--" + model_id.replace("/", "--"))
    if os.path.exists(cache_path):
        print(f"Model already cached at {cache_path}")
    else:
        # Download model
        snapshot_download(
            repo_id=model_id,
            cache_dir=hf_home,
            allow_patterns=["*.safetensors", "*.json", "*.txt", "*.md"],
        )
        print(f"Model downloaded successfully to {hf_home}")
except Exception as e:
    print(f"Error downloading model: {e}")
    raise
