import logging
import os
from typing import List

import torch
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from transformers import AutoModelForCausalLM, AutoTokenizer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Local Inference Server")

model = None
tokenizer = None
device = "cpu"
loaded_model_id = None


class Message(BaseModel):
    role: str
    content: str


class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[Message]
    max_tokens: int = 64
    temperature: float = 0.7
    top_p: float = 0.9


def build_prompt(messages: List[Message]) -> str:
    system_message = ""
    user_message = ""

    for msg in messages:
        if msg.role == "system" and not system_message:
            system_message = msg.content.strip()
        elif msg.role == "user":
            user_message = msg.content.strip()

    if system_message:
        return f"{system_message}\n\nUser: {user_message}\n\nAssistant:"
    return f"User: {user_message}\n\nAssistant:"


@app.on_event("startup")
async def startup_event() -> None:
    global model, tokenizer, device, loaded_model_id

    try:
        model_id = os.getenv("MODEL_ID", "Qwen/Qwen2.5-0.5B-Instruct")
        device = "cpu"

        logger.info("Loading model: %s", model_id)
        logger.info("Using device: %s", device)

        tokenizer = AutoTokenizer.from_pretrained(model_id)
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            torch_dtype=torch.float32,
        )
        model.to(device)
        model.eval()
        loaded_model_id = model_id

        if tokenizer.pad_token_id is None and tokenizer.eos_token_id is not None:
            tokenizer.pad_token = tokenizer.eos_token

        logger.info("Model loaded successfully")
    except Exception as exc:
        logger.exception("Failed to load model")
        model = None
        tokenizer = None
        loaded_model_id = None
        raise exc


@app.get("/health")
async def health():
    if model is None or tokenizer is None:
        return JSONResponse({"status": "loading"}, status_code=503)
    return {"status": "ok", "model": loaded_model_id}


@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    global model, tokenizer

    if model is None or tokenizer is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        prompt = build_prompt(request.messages)
        inputs = tokenizer(prompt, return_tensors="pt")
        inputs = {key: value.to(device) for key, value in inputs.items()}

        with torch.no_grad():
            outputs = model.generate(
                input_ids=inputs["input_ids"],
                attention_mask=inputs.get("attention_mask"),
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                do_sample=request.temperature > 0,
                pad_token_id=tokenizer.pad_token_id,
                eos_token_id=tokenizer.eos_token_id,
            )

        generated_tokens = outputs[0][inputs["input_ids"].shape[1] :]
        generated_part = tokenizer.decode(generated_tokens, skip_special_tokens=True).strip()

        return {
            "id": "chatcmpl-local",
            "object": "chat.completion",
            "created": 0,
            "model": loaded_model_id or request.model,
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": generated_part,
                    },
                    "finish_reason": "stop",
                }
            ],
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Inference error")
        raise HTTPException(status_code=500, detail=f"Inference error: {exc}")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)
