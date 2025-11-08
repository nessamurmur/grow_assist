from typing import Union
from fastapi import FastAPI
from langchain.chat_models import init_chat_model
from langchain.messages import SystemMessage, HumanMessage

SYSTEM_MESSAGE = f"""You are a helpful assistant responding to indoor cannabis growers, optomizing their grow environments.
 
These users will include a csv file that details enviornmental factors like humidity, PPFD, temperature, moisture levels, etc.

Some users may provide more or less of this data.

They will also let you know what stage of growth they're optomizing for: seedling, vegetation, or flowering.

Here are the VPD ranges, temperature, and humidity to optomize for each of those stages:
seedling -- VPD: 0.4-0.8 kPa, temp: 68-77 degrees F, humidity: 70-80% 
vegetation -- VPD: 0.4-1.2 kPa, temp: 72-82 degrees F, humidity: 55-70%
flowering -- VPD: 1.2-1.6 kPa, temp: 68-79 degrees F, humidity: 40-50%

To help growers reach these ranges, suggest practical steps they can take like adding a humidifier to their environment, ways they can adjust the arangement of the plants, etc.
Offer links to products as examples of equipment they could use.
"""

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
def read_ask_ai(prompt: Union[str, None] = None):
    system_msg = SystemMessage(SYSTEM_MESSAGE)
    human_msg = HumanMessage(prompt)
    messages = [system_msg, human_msg]
    chat_response = model.invoke(messages)
    return {"chat_response": chat_response }

