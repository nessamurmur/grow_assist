from typing import Union
from pathlib import Path
from fastapi import FastAPI, Request, Form
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from langchain.chat_models import init_chat_model
from langchain.messages import SystemMessage, HumanMessage

SYSTEM_MESSAGE = f"""You are a helpful assistant responding to indoor cannabis growers, optomizing their grow environments.
 
These users will include a csv file that details enviornmental factors like humidity, PPFD, temperature, moisture levels, etc.

Some users may provide more or less of this data.

They will also let you know what stage of growth they're optomizing for: seedling, vegetation, or flowering.

Here are the VPD ranges, temperature, and humidity to optomize for each of those stages:
seedling -- VPD: 0.4-0.8 kPa, temp: 68-77 degrees F, humidity: 70-80% 
vegetation -- VPD: 0.8-1.2 kPa, temp: 72-82 degrees F, humidity: 55-70%
flowering -- VPD: 1.2-1.6 kPa, temp: 68-79 degrees F, humidity: 40-50%

To help growers reach these ranges, suggest practical steps they can take like adding a humidifier to their environment, ways they can adjust the arangement of the plants, etc.
Offer links to products as examples of equipment they could use.
"""

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
TEMPLATE_DIR = BASE_DIR / "templates"

app = FastAPI()

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory=TEMPLATE_DIR)

_model = None

def get_model():
    """Get or initialize the chat model."""
    global _model
    if _model is None:
        _model = init_chat_model(
            "google_genai:gemini-2.5-flash-lite",
            temperature=0.7,
            timeout=30,
            max_tokens=500,
        )
    return _model

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/ask_ai", response_class=HTMLResponse)
async def ask_ai(request: Request, prompt: str = Form(...)):
    system_msg = SystemMessage(SYSTEM_MESSAGE)
    human_msg = HumanMessage(prompt)
    messages = [system_msg, human_msg]

    model = get_model()
    chat_response = model.invoke(messages)

    response_text = chat_response.content if hasattr(chat_response, 'content') else str(chat_response)

    return templates.TemplateResponse("index.html", {
        "request": request,
        "prompt": prompt,
        "response": response_text
    })

