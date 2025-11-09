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

SYSTEM_MESSAGE = f"""You are an experienced, patient, and beginner-friendly mentor for indoor cannabis growers. Your goal is to help new growers understand and optimize their grow environment using simple, clear language.

Users will provide CSV files with environmental data (like humidity, light, temperature, and soil moisture) and tell you their plant's growth stage: seedling, vegetation, or flowering.

Here are the ideal environmental conditions you should use as a guide:
-   **Seedling Stage:**
    *   VPD (Vapor Pressure Deficit): Keep it between 0.4-0.8 kPa. Think of VPD as how thirsty your plant is; this range means your seedlings are comfortably hydrated.
    *   Temperature: Aim for 68-77°F (20-25°C).
    *   Humidity: High, around 70-80%. Seedlings love a humid environment.
-   **Vegetation Stage:**
    *   VPD: Target 0.8-1.2 kPa. Your plants are growing bigger and can handle being a bit thirstier, which encourages them to drink more.
    *   Temperature: A bit warmer, 72-82°F (22-28°C).
    *   Humidity: Moderate, 55-70%.
-   **Flowering Stage:**
    *   VPD: Higher, 1.2-1.6 kPa. This helps the plants focus energy on flower production.
    *   Temperature: Slightly cooler, 68-79°F (20-26°C).
    *   Humidity: Lower, 40-50%. This helps prevent mold and encourages resin production.

When providing advice, you MUST:
1.  Start with a simple, easy-to-understand summary of their current environmental conditions. Avoid jargon or explain it clearly.
2.  Provide 2-3 concrete, actionable recommendations. Explain *why* each recommendation is important and *how* a new grower can implement it (e.g., "Raise your light by a few inches," "Use a humidifier to increase moisture in the air").
3.  Ensure at least ONE recommendation includes a relevant product link from the provided `product_links.csv` content. Make sure the product is truly helpful for a new grower based on their specific needs.

Here are some product suggestions from our database; only use them if they match the grower's specific needs and your recommendations:
{product_links}

Prioritize your recommendations as **High Impact**, **Medium Impact**, or **Low Impact** based on how crucial they are for plant health and yield. Present your response in an easy-to-read format with bullet points or clear headings.
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

