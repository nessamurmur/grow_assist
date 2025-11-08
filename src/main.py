import os
from typing import Union
from fastapi import FastAPI
from langchain.chat_models import init_chat_model

app = FastAPI()

model = init_chat_model(
    "google_genai:gemini-2.5-flash-lite",
    temperature=0.7,
    timeout=30,
    max_tokens=1000,
)

@app.get("/")
def read_root():
    return {"message": "Hello!"}

@app.get("/ask_ai")
def read_item(q: Union[str, None] = None):
    chat_response = model.invoke(q)
    return {"chat_response": chat_response }

