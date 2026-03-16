import logging
import os
import uvicorn
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="LLM FastAPI Sidecar")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

INFERENCE_HOST = os.getenv("INFERENCE_HOST", "localhost")
INFERENCE_PORT = os.getenv("INFERENCE_PORT", "8001")
MODEL_ID = os.getenv("MODEL_ID", "Qwen/Qwen2.5-0.5B-Instruct")
SYSTEM_MESSAGE = os.getenv(
    "SYSTEM_MESSAGE",
    "You are a helpful assistant. Answer in 1-2 sentences only. Be concise and brief.",
)
INFERENCE_TIMEOUT = 120

INFERENCE_URL = f"http://{INFERENCE_HOST}:{INFERENCE_PORT}"


class GenerateRequest(BaseModel):
    prompt: str


@app.get("/health/live")
async def health_live():
    return {"status": "ok"}


@app.get("/health")
async def health_ready():
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{INFERENCE_URL}/health", timeout=5)
            if response.status_code == 200:
                return {"status": "ok"}
            return JSONResponse({"status": "inference_unavailable"}, status_code=503)
    except Exception as exc:
        logger.error("Readiness check failed: %s", exc)
        return JSONResponse({"status": "error"}, status_code=503)


@app.post("/generate")
async def generate(request: GenerateRequest):
    try:
        inference_request = {
            "model": MODEL_ID,
            "messages": [
                {"role": "system", "content": SYSTEM_MESSAGE},
                {"role": "user", "content": request.prompt},
            ],
            "max_tokens": 32,
            "temperature": 0.7,
            "top_p": 0.9,
        }

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{INFERENCE_URL}/v1/chat/completions",
                json=inference_request,
                timeout=INFERENCE_TIMEOUT,
            )

        if response.status_code == 503:
            raise HTTPException(status_code=503, detail="Model loading")
        if response.status_code != 200:
            logger.error("Inference error response: %s", response.text)
            raise HTTPException(status_code=502, detail="Unexpected inference response")

        data = response.json()
        generated_text = data["choices"][0]["message"]["content"]
        return {"text": generated_text}

    except httpx.ConnectError:
        logger.error("Cannot connect to inference server")
        raise HTTPException(status_code=503, detail="Inference service unavailable")
    except httpx.TimeoutException:
        logger.error("Inference timeout")
        raise HTTPException(status_code=504, detail="Inference timeout")
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Unexpected API error")
        raise HTTPException(status_code=500, detail=f"Internal error: {exc}")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
