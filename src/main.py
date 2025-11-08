from pathlib import Path
import io
import csv
from fastapi import FastAPI, Request, Form, File, UploadFile
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from langchain.chat_models import init_chat_model
from langchain.messages import SystemMessage, HumanMessage
from .models import AnalysisResponse

SYSTEM_MESSAGE = """You are a helpful assistant responding to indoor cannabis growers, optimizing their grow environments.
 
These users will include a CSV file that details environmental factors like humidity, PPFD, temperature, moisture levels, etc.

Some users may provide more or less of this data.

They will also let you know what stage of growth they're optimizing for: seedling, vegetation, or flowering.

Here are the VPD ranges, temperature, and humidity to optimize for each of those stages:
seedling -- VPD: 0.4-0.8 kPa, temp: 68-77 degrees F, humidity: 70-80% 
vegetation -- VPD: 0.8-1.2 kPa, temp: 72-82 degrees F, humidity: 55-70%
flowering -- VPD: 1.2-1.6 kPa, temp: 68-79 degrees F, humidity: 40-50%

You must provide:
1. A brief summary of the current environmental conditions
2. Between 2-3 actionable recommendations to improve their grow environment
3. At least ONE recommendation MUST include a product link

For product recommendations:
- Provide specific product names from reputable grow equipment retailers
- IMPORTANT: Include direct product URLs from hydroponics/grow equipment stores (e.g., Spider Farmer, AC Infinity, Gorilla Grow Tent, HTG Supply, Grow Generation)
- DO NOT use Amazon links - only use links from specialized grow equipment retailers
- Verify that product URLs are real and working links to actual products
- Optionally include a price range estimate

Prioritize recommendations as high, medium, or low based on their impact on plant health.
"""

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
TEMPLATE_DIR = BASE_DIR / "templates"

app = FastAPI()

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory=TEMPLATE_DIR)

_model = None
_structured_model = None

def get_model():
    """Get or initialize the chat model."""
    global _model
    if _model is None:
        _model = init_chat_model(
            "google_genai:gemini-2.5-flash-lite",
            temperature=0.7,
            timeout=30,
            max_tokens=1000,
        )
    return _model

def get_structured_model():
    """Get or initialize the structured chat model."""
    global _structured_model
    if _structured_model is None:
        base_model = get_model()
        _structured_model = base_model.with_structured_output(AnalysisResponse)
    return _structured_model

@app.get("/", response_class=HTMLResponse)
async def read_root(request: Request):
    return templates.TemplateResponse(request, "index.html")

def parse_csv_data(file_content: str) -> str:
    """Parse CSV file content and format it as a readable string."""
    csv_reader = csv.DictReader(io.StringIO(file_content))
    rows = list(csv_reader)

    if not rows:
        return "No data found in CSV file."

    # Format the data summary
    data_summary = []
    data_summary.append(f"Environmental data ({len(rows)} readings):")
    data_summary.append("\nColumn headers: " + ", ".join(rows[0].keys()))
    data_summary.append("\nData:")

    for i, row in enumerate(rows, 1):
        row_data = ", ".join([f"{k}: {v}" for k, v in row.items() if v])
        data_summary.append(f"Reading {i}: {row_data}")

    return "\n".join(data_summary)


@app.post("/analyze", response_class=HTMLResponse)
async def analyze(
    request: Request,
    growth_stage: str = Form(...),
    csv_file: UploadFile = File(...)
):
    """Analyze environmental data from CSV for the selected growth stage."""
    # Read and parse CSV file
    file_content = await csv_file.read()
    csv_text = file_content.decode('utf-8')
    parsed_data = parse_csv_data(csv_text)

    # Build the user prompt with growth stage and CSV data
    user_prompt = f"""Growth Stage: {growth_stage}

{parsed_data}

Please analyze this environmental data for the {growth_stage} stage and provide recommendations for optimization.
"""

    system_msg = SystemMessage(SYSTEM_MESSAGE)
    human_msg = HumanMessage(user_prompt)
    messages = [system_msg, human_msg]

    structured_model = get_structured_model()
    analysis_response = structured_model.invoke(messages)

    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "growth_stage": growth_stage,
            "csv_filename": csv_file.filename,
            "analysis": analysis_response
        }
    )

