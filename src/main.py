from pathlib import Path
import io
import csv
from fastapi import FastAPI, Request, Form, File, UploadFile
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.messages import SystemMessage, HumanMessage
from .models import AnalysisResponse

product_links = ""

try:
    with open("./src/product_links.csv") as file:
        product_links = file.readlines()
except FileNotFoundError:
    print("Please include product_links.csv")

SYSTEM_MESSAGE = f"""You are a helpful assistant for indoor cannabis growers optimizing their environments.

Users provide CSV files with environmental data (humidity, PPFD, temperature, moisture) and specify their growth stage: seedling, vegetation, or flowering.

VPD ranges, temperature, and humidity targets:
- seedling: VPD 0.4-0.8 kPa, temp 68-77°F, humidity 70-80%
- vegetation: VPD 0.8-1.2 kPa, temp 72-82°F, humidity 55-70%
- flowering: VPD 1.2-1.6 kPa, temp 68-79°F, humidity 40-50%

You MUST provide:
1. Brief summary of current environmental conditions
2. 2-3 actionable recommendations to improve the grow environment
3. At least ONE recommendation MUST include a product link

You can find products to suggest in this csv content:
{product_links}

Verify the product matches the grower's needs

Prioritize recommendations as high, medium, or low based on impact on plant health.
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
        _model = ChatGoogleGenerativeAI(
            model="gemini-2.5-flash",
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
    file_content = await csv_file.read()
    csv_text = file_content.decode('utf-8')
    parsed_data = parse_csv_data(csv_text)

    user_prompt = f"""Growth Stage: {growth_stage}

{parsed_data}

Analyze this environmental data for the {growth_stage} stage.

Provide recommendations for optimization with product links.
"""

    system_msg = SystemMessage(SYSTEM_MESSAGE)
    human_msg = HumanMessage(user_prompt)
    messages = [system_msg, human_msg]

    base_model = get_model()
    grounded_response = base_model.invoke(
        messages,
    )

    structured_model = get_structured_model()
    structure_prompt = f"""Convert this analysis into the required structured format.

Original Analysis with Researched Products:
{grounded_response.content}

Ensure all product URLs are included exactly as provided."""

    analysis_response = structured_model.invoke([
        HumanMessage(structure_prompt),
    ])

    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "growth_stage": growth_stage,
            "csv_filename": csv_file.filename,
            "analysis": analysis_response
        }
    )

