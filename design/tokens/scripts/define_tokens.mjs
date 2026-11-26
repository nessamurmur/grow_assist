// Writes the DTCG files. Edit this script, then run it again.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

function color(hex, alpha) {
  const h = hex.slice(1);
  const n = parseInt(h, 16);
  const value = {
    colorSpace: "srgb",
    components: [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255].map(
      (channel) => Math.round(channel * 100000) / 100000,
    ),
    hex,
  };
  if (alpha !== undefined) value.alpha = alpha;
  return value;
}

function tok(type, value, description) {
  const token = { $value: value, $description: description };
  if (type) token.$type = type;
  return token;
}

const paint = (hex, description, alpha) => tok("color", color(hex, alpha), description);
const dim = (value, unit, description) => tok("dimension", { value, unit }, description);
const num = (value, description) => tok("number", value, description);
const weight = (value, description) => tok("fontWeight", value, description);
const alias = (path, description) => tok(null, `{${path}}`, description);

function shadow(hex, alpha, x, y, blur, spread, description) {
  return tok(
    "shadow",
    {
      color: { $type: "color", $value: color(hex, alpha) },
      offsetX: { value: x, unit: "px" },
      offsetY: { value: y, unit: "px" },
      blur: { value: blur, unit: "px" },
      spread: { value: spread, unit: "px" },
    },
    description,
  );
}

function typeStyle(sizePath, weightPath, leadingPath, description, tracking = 0) {
  return tok(
    "typography",
    {
      fontFamily: "{primitive.font.family.system}",
      fontSize: `{${sizePath}}`,
      fontWeight: `{${weightPath}}`,
      letterSpacing: { value: tracking, unit: "px" },
      lineHeight: `{${leadingPath}}`,
    },
    description,
  );
}

const systemFamily = [
  "-apple-system",
  "BlinkMacSystemFont",
  "Segoe UI",
  "Roboto",
  "Oxygen",
  "Ubuntu",
  "Cantarell",
  "Fira Sans",
  "Droid Sans",
  "Helvetica Neue",
  "sans-serif",
];

const foundation = {
  $description:
    "Grow Assist tokens. Format module 2025.10. Semantic colors in this file are the dark theme, which is the only theme the stylesheet ships. Light overrides live in grow_assist.light.tokens.json. The resolver default is dark.",
  primitive: {
    $description: "Generic scales. Names are not domain terms.",
    color: {
      white: paint("#ffffff", "Button label. The stylesheet writes the keyword white."),
      black: paint("#000000", "Shadow ink. The stylesheet writes rgba(0, 0, 0, 0.3)."),
      slate: {
        "50": paint("#f8fafc", "Light theme page canvas. Not in the current stylesheet."),
        "100": paint("#f1f5f9", "Dark theme text. CSS custom property --text-primary."),
        "200": paint("#e2e8f0", "Draft dark secondary text. CSS --text-secondary is #cbd5e1, which is Lc -70.5 on the recommendation surface."),
        "300": paint("#cbd5e1", "CSS --text-secondary. Recorded. Semantic text uses slate.200 so recommendation copy clears APCA Lc 75."),
        "400": paint("#94a3b8", "CSS --text-muted and, in this draft, the dark border."),
        "500": paint("#64748b", "Light theme border. Not in the current stylesheet."),
        "600": paint("#475569", "Light theme muted text. Not in the current stylesheet."),
        "700": paint("#334155", "CSS --surface-hover and --border."),
        "800": paint("#1e293b", "CSS --surface."),
        "900": paint("#0f172a", "CSS --background."),
      },
      green: {
        "100": paint("#d1fae5", "CSS --primary-light. Defined on :root and read by no rule. Used here as the light summary wash."),
        "200": paint("#a7f3d0", "Draft dark summary heading. #6ee7b7 on the summary surface is Lc -73.8."),
        "300": paint("#6ee7b7", "Draft dark-theme green text. Replaces #10b981 where that green is body text."),
        "500": paint("#10b981", "CSS --primary."),
        "600": paint("#059669", "CSS --primary-hover. Recorded from the stylesheet. Semantic tokens do not reference it."),
        "700": paint("#047857", "Light theme analyze fill. White on this green is 5.48:1."),
        "800": paint("#065f46", "Draft light-theme green text."),
        "950": paint("#022c22", "Dark theme analyze label. Dark text on #6ee7b7."),
      },
      violet: {
        "300": paint("#c4b5fd", "Recorded so a large-text violet can clear WCAG. The stylesheet uses #8b5cf6."),
        "500": paint("#8b5cf6", "CSS --secondary. Used by the header gradient. No semantic token references it."),
      },
      red: {
        "200": paint("#fecaca", "Draft dark problem text and high-priority badge text."),
        "300": paint("#fca5a5", "CSS problem text and high badge text. Draft high-priority edge. #f87171 on #334155 is Lc -39."),
        "400": paint("#f87171", "Recorded candidate for the high edge. #ef4444 on #334155 is 2.75:1. #f87171 is Lc -39, so the edge uses red.300."),
        "500": paint("#ef4444", "CSS high-priority edge. 2.75:1 on #334155. Not referenced."),
        "600": paint("#dc2626", "Draft light high-priority accent."),
        "800": paint("#991b1b", "Draft light problem text."),
        "900": paint("#7f1d1d", "Draft light high-priority badge text."),
      },
      amber: {
        "200": paint("#fde68a", "Draft dark medium-priority badge text."),
        "500": paint("#f59e0b", "CSS priority-medium accent. Kept. It clears 3:1 on #334155."),
        "700": paint("#b45309", "Draft light medium-priority accent. #d97706 on #f1f5f9 is 2.91:1."),
        "900": paint("#78350f", "Draft light medium-priority badge text."),
      },
      blue: {
        "200": paint("#bfdbfe", "Draft dark low-priority badge text."),
        "300": paint("#93c5fd", "CSS low badge text. Draft low-priority edge. #60a5fa on #334155 is Lc -42."),
        "400": paint("#60a5fa", "Recorded candidate. Lc -42 on #334155, so the edge uses blue.300."),
        "500": paint("#3b82f6", "CSS low-priority edge. 2.82:1 on #334155. Not referenced."),
        "600": paint("#2563eb", "Draft light low-priority accent."),
        "900": paint("#1e3a8a", "Draft light low-priority badge text."),
      },
      ink: {
        badgeHigh: paint("#3f1d24", "Draft dark high-priority badge surface. Replaces a 20% red wash."),
        badgeMedium: paint("#3b2a14", "Draft dark medium-priority badge surface."),
        badgeLow: paint("#1e2a44", "Draft dark low-priority badge surface."),
        summary: paint("#12362f", "Draft dark summary surface. Replaces the green-to-violet gradient wash."),
        muted: paint("#a8b3c4", "Draft dark muted text. #94a3b8 on #334155 is 4.04:1. This step clears 4.5:1 on canvas, surface, and raised."),
      },
      wash: {
        high: paint("#fee2e2", "Draft light high-priority badge surface."),
        medium: paint("#fef3c7", "Draft light medium-priority badge surface."),
        low: paint("#dbeafe", "Draft light low-priority badge surface."),
      },
    },
    space: {
      $description: "4px steps, stored in rem so they follow the root font size. space.4 is 1rem.",
      "0": dim(0, "rem", "Reset margin and padding."),
      "1": dim(0.25, "rem", "4px. The 0.25rem gaps in stage details and product details."),
      "2": dim(0.5, "rem", "8px. Also the merged badge padding. CSS badge padding-block is 0.35rem, the only off-scale space."),
      "3": dim(0.75, "rem", "12px."),
      "4": dim(1, "rem", "16px. The most used space in the stylesheet."),
      "5": dim(1.25, "rem", "20px."),
      "6": dim(1.5, "rem", "24px. CSS --spacing."),
      "8": dim(2, "rem", "32px."),
      "12": dim(3, "rem", "48px."),
    },
    font: {
      family: {
        system: tok("fontFamily", systemFamily, "The body stack in priv/static/styles.css."),
        brandSans: tok(
          "fontFamily",
          ["Inter", "-apple-system", "BlinkMacSystemFont", "Segoe UI", "Roboto", "sans-serif"],
          "Proposal. The blog loads Inter. The shell does not. No semantic font references this token.",
        ),
        brandSerif: tok(
          "fontFamily",
          ["Source Serif 4", "Georgia", "Times New Roman", "serif"],
          "Proposal. The blog uses Source Serif 4 for titles. The shell does not. No semantic font references this token.",
        ),
      },
      size: {
        "12": dim(0.75, "rem", "12px at a 16px root. Priority badge only."),
        "14": dim(0.875, "rem", "14px. Merges 0.8rem, 0.85rem, and 0.9rem."),
        "16": dim(1, "rem", "16px. Merges 0.95rem and 1rem."),
        "18": dim(1.125, "rem", "18px. Merges 1.1rem."),
        "20": dim(1.25, "rem", "20px. Merges 1.2rem. Also the compact section title, which is already 1.25rem."),
        "24": dim(1.5, "rem", "24px section title."),
        "32": dim(2, "rem", "32px compact page title and the product emoji."),
        "40": dim(2.5, "rem", "40px. One-off. The stacked layout title between the 32px phone title and the 48px desktop title."),
        "48": dim(3, "rem", "48px desktop page title and the stage emoji."),
      },
      weight: {
        regular: weight(400, "User-agent initial. The stylesheet never sets 400. Body text inherits it."),
        medium: weight(500, "Labels and the VPD line."),
        semibold: weight(600, "The weight used most often."),
        bold: weight(700, "The page title only."),
      },
      leading: {
        body: num(1.6, "Body line height."),
        prose: num(1.75, "Merged from 1.7 on the summary and recommendation, and 1.8 on .ai-message. That class is not in the shell."),
      },
    },
    radius: {
      "1": dim(4, "px", "Merged from the 5px scrollbar thumb."),
      "2": dim(8, "px", "Fields, analyze button, product link, response container."),
      "3": dim(12, "px", "CSS --radius. Also merges the 10px product block."),
      full: dim(999, "px", "Merged from the 20px badge radius so a wrapping badge stays a pill."),
    },
    border: {
      hairline: dim(1, "px", "Section, footer, and badge borders."),
      field: dim(2, "px", "Fields, stage, recommendation, and product link borders."),
      accent: dim(4, "px", "Summary and priority edge."),
    },
    shadow: {
      rest: shadow("#000000", 0.3, 0, 4, 12, 0, "Offset of the analyze button and the product link, CSS 0 4px 12px. The stylesheet tints that shadow green. This draft uses 30% black, the same ink as the section shadow."),
      hover: shadow("#000000", 0.3, 0, 8, 20, 0, "One hover shadow. The button hover is 0 6px 20px at 40% green, the card hover is 0 8px 20px at 30% black, and the stage hover is 0 8px 20px at 20% green."),
      overlay: shadow("#000000", 0.3, 0, 10, 30, 0, "Section shadow. CSS 0 10px 30px var(--shadow)."),
    },
    duration: {
      fast: tok("duration", { value: 200, unit: "ms" }, "Field transition. The only 0.2s duration."),
      moderate: tok("duration", { value: 300, unit: "ms" }, "Hover transitions."),
    },
    easing: {
      standard: tok("cubicBezier", [0.25, 0.1, 0.25, 1], "CSS keyword ease."),
    },
    size: {
      shellMax: dim(1200, "px", "One-off. The page column max-width."),
      responseMin: dim(200, "px", "One-off. Empty response min-height."),
      productMin: dim(200, "px", "One-off. Product row min-width before it wraps."),
      lift: dim(2, "px", "Hover lift for the button, product link, and recommendation."),
      liftStage: dim(4, "px", "One-off. Stage cards lift 4px. They are the selection target, so the lift stays larger than the button."),
    },
    breakpoint: {
      compact: dim(640, "px", "One-off. Phone padding, stacked stage cards, and the compact type step."),
      stack: dim(968, "px", "One-off. The width where the form and the recommendations stop sitting side by side. Not merged with 640px or with 1024px."),
    },
  },
  semantic: {
    $description:
      "Names from the Gleam modules. shell, focus, and apiKey are proposals. See design/tokens/README.md.",
    color: {
      shell: {
        $description:
          "Proposal. shell.gleam is the view module. There is no Shell type. Confirm the name with NJ before code agents use it.",
        canvas: paint("#0f172a", "Page background. CSS --background."),
        surface: paint("#1e293b", "Section background. CSS --surface."),
        raised: paint("#334155", "Recommendation surface. CSS --surface-hover."),
        text: paint("#f1f5f9", "Primary text. CSS --text-primary."),
        textSecondary: paint("#e2e8f0", "Secondary text. Shifted from #cbd5e1 so recommendation descriptions clear APCA Lc 75 on the raised surface."),
        muted: paint("#a8b3c4", "Footer text. Shifted from #94a3b8 so it clears 4.5:1 on raised as well as on canvas."),
        border: paint("#a8b3c4", "Borders. CSS #334155 fails 3:1. #94a3b8 passes WCAG and is Lc -42 on raised, under the APCA UI bar of 45, so the border uses the muted ink."),
      },
      status: {
        $description: "shell.Status: Waiting, Loading, Problem, Ready. Ready has no color of its own. It uses summary and recommendation.",
        waiting: alias("semantic.color.shell.textSecondary", "Waiting placeholder. CSS uses --text-muted. Secondary text is Lc -79 on the canvas. Muted is about Lc -60."),
        loading: alias("semantic.color.shell.textSecondary", "Loading line. CSS --text-secondary, unchanged."),
        problem: paint("#fecaca", "Problem text. CSS #fca5a5 passes WCAG and is about Lc -65. #fecaca is the draft for body-size error text."),
      },
      priority: {
        $description: "analysis.Priority: High, Medium, Low.",
        high: {
          accent: paint("#fca5a5", "High priority edge."),
          badgeText: paint("#fecaca", "High priority badge label."),
          badgeSurface: paint("#3f1d24", "High priority badge surface. CSS is rgba(239, 68, 68, 0.2) over #334155."),
        },
        medium: {
          accent: paint("#f59e0b", "Medium priority edge. Kept. 4.82:1 on #334155."),
          badgeText: paint("#fde68a", "Medium priority badge label. CSS #fcd34d."),
          badgeSurface: paint("#3b2a14", "Medium priority badge surface."),
        },
        low: {
          accent: paint("#93c5fd", "Low priority edge."),
          badgeText: paint("#bfdbfe", "Low priority badge label. CSS #93c5fd."),
          badgeSurface: paint("#1e2a44", "Low priority badge surface."),
        },
      },
      stage: {
        $description: "shell.Stage: Seedling, Vegetation, Flowering. The three stages share one color. The stylesheet does not color them differently.",
        vpd: paint("#6ee7b7", "VPD line on a stage card. VPD is prompt language, not a Gleam type. CSS --primary as text is Lc -52 at 0.85rem."),
        selected: paint("#10b981", "Selected stage border. CSS --primary. 7.04:1 on the canvas."),
      },
      summary: {
        $description: "AnalysisResponse summary.",
        heading: paint("#a7f3d0", "Summary heading. Lighter than the VPD line because the summary surface is lighter than the canvas."),
        surface: paint("#12362f", "Summary surface. CSS is a 135deg gradient of 10% green and 10% violet over the canvas."),
      },
      productLink: {
        $description: "analysis.ProductLink.",
        price: paint("#6ee7b7", "price_range text."),
        accent: paint("#10b981", "Product block border. CSS --primary. Passes 3:1 on the canvas."),
        action: alias("semantic.color.analyze.fill", "View product fill. The stylesheet uses the same gradient as Analyze."),
      },
      analyze: {
        $description: "The AnalyzeClicked action.",
        fill: paint("#6ee7b7", "Dark analyze fill. A #047857 fill on the #1e293b section is 2.67:1, so the dark theme uses the light green and dark label instead of white on green."),
        text: alias("primitive.color.green.950", "Dark analyze label."),
      },
      focus: paint("#10b981", "Proposal. No domain term for the keyboard focus indicator. This is the CSS focus border color, which already passes 3:1. The 10% ring does not."),
    },
    shadow: {
      focus: shadow("#10b981", 1, 0, 0, 0, 3, "Solid 3px focus ring in the dark theme."),
    },
    font: {
      display: typeStyle("primitive.font.size.48", "primitive.font.weight.bold", "primitive.font.leading.body", "Page title at the desktop size. The h1 does not set its own line height."),
      displayStacked: typeStyle("primitive.font.size.40", "primitive.font.weight.bold", "primitive.font.leading.body", "Page title when the columns stack, under 968px."),
      displayCompact: typeStyle("primitive.font.size.32", "primitive.font.weight.bold", "primitive.font.leading.body", "Page title under 640px."),
      section: typeStyle("primitive.font.size.24", "primitive.font.weight.semibold", "primitive.font.leading.body", "Section heading."),
      sectionCompact: typeStyle("primitive.font.size.20", "primitive.font.weight.semibold", "primitive.font.leading.body", "Section heading under 640px."),
      body: typeStyle("primitive.font.size.16", "primitive.font.weight.regular", "primitive.font.leading.body", "Body, fields, and the analyze label size."),
      prose: typeStyle("primitive.font.size.16", "primitive.font.weight.regular", "primitive.font.leading.prose", "Summary and recommendation description."),
      label: typeStyle("primitive.font.size.16", "primitive.font.weight.medium", "primitive.font.leading.body", "Field labels. CSS is 0.95rem."),
      stageName: typeStyle("primitive.font.size.18", "primitive.font.weight.semibold", "primitive.font.leading.body", "Stage name. CSS is 1.1rem."),
      small: typeStyle("primitive.font.size.14", "primitive.font.weight.regular", "primitive.font.leading.body", "Footer, VPD line, API key hint, stage temperature and humidity."),
      recommendation: typeStyle("primitive.font.size.20", "primitive.font.weight.semibold", "primitive.font.leading.body", "Recommendation title. CSS is 1.2rem."),
      recommendationCompact: typeStyle("primitive.font.size.18", "primitive.font.weight.semibold", "primitive.font.leading.body", "Recommendation title under 640px. CSS is 1.1rem."),
      summary: typeStyle("primitive.font.size.18", "primitive.font.weight.semibold", "primitive.font.leading.body", "Summary heading. CSS is 1.1rem."),
      badge: typeStyle("primitive.font.size.12", "primitive.font.weight.semibold", "primitive.font.leading.body", "Priority badge. The 0.75rem size stays because it is uppercase. Tracking stays 0.5px.", 0.5),
      analyze: typeStyle("primitive.font.size.16", "primitive.font.weight.semibold", "primitive.font.leading.body", "Analyze and the product link label."),
    },
  },
  component: {
    $description: "Grower-facing parts. Each value aliases a semantic or primitive token.",
    shell: {
      $description: "Proposal. Page chrome. Confirm shell with NJ.",
      canvas: alias("semantic.color.shell.canvas", "Page background."),
      surface: alias("semantic.color.shell.surface", "Section background."),
      text: alias("semantic.color.shell.text", "Default text."),
      headerTitle: alias("semantic.font.display", "Page title."),
      headerTagline: alias("semantic.color.shell.textSecondary", "The line under the title."),
      footer: alias("semantic.color.shell.muted", "Footer line."),
      maxWidth: alias("primitive.size.shellMax", "Page column."),
    },
    stage: {
      surface: alias("semantic.color.shell.canvas", "Stage card background."),
      border: alias("semantic.color.shell.border", "Stage card border."),
      selected: alias("semantic.color.stage.selected", "Selected stage border."),
      name: alias("semantic.color.shell.text", "Seedling, Vegetation, or Flowering."),
      vpd: alias("semantic.color.stage.vpd", "VPD target on the card."),
      detail: alias("semantic.color.shell.textSecondary", "Temperature and humidity. CSS uses --text-muted. Those numbers are part of the job."),
    },
    readings: {
      $description: "Model.readings. Readings is a field, not a type.",
      surface: alias("semantic.color.shell.canvas", "Readings field background."),
      text: alias("semantic.color.shell.text", "Readings text."),
      border: alias("semantic.color.shell.border", "Readings border."),
      placeholder: alias("semantic.color.status.waiting", "Readings placeholder."),
    },
    apiKey: {
      $description: "Proposal. Model.api_key is a field. There is no ApiKey type. The brief says this field should not stay central.",
      surface: alias("semantic.color.shell.canvas", "API key field background."),
      text: alias("semantic.color.shell.text", "API key text."),
      border: alias("semantic.color.shell.border", "API key border."),
      hint: alias("semantic.color.shell.textSecondary", "The hint under the field. Muted text is about Lc -60 here, under the APCA body bar."),
    },
    analyze: {
      fill: alias("semantic.color.analyze.fill", "Analyze button fill."),
      text: alias("semantic.color.analyze.text", "Analyze button label."),
      font: alias("semantic.font.analyze", "Analyze label type."),
    },
    focus: {
      $description: "Proposal. No domain term.",
      color: alias("semantic.color.focus", "Focus border and ring color."),
      ring: alias("semantic.shadow.focus", "Focus ring."),
    },
    status: {
      waiting: alias("semantic.color.status.waiting", "Empty recommendations copy."),
      loading: alias("semantic.color.status.loading", "Loading copy."),
      problem: alias("semantic.color.status.problem", "Problem copy."),
    },
    summary: {
      surface: alias("semantic.color.summary.surface", "Summary block."),
      heading: alias("semantic.color.summary.heading", "Summary heading color."),
      text: alias("semantic.color.shell.text", "Summary paragraph."),
      font: alias("semantic.font.prose", "Summary paragraph type."),
    },
    recommendation: {
      surface: alias("semantic.color.shell.raised", "Recommendation surface."),
      title: alias("semantic.color.shell.text", "Recommendation title color."),
      description: alias("semantic.color.shell.textSecondary", "Recommendation description."),
    },
    priority: {
      high: {
        accent: alias("semantic.color.priority.high.accent", "High edge."),
        badgeText: alias("semantic.color.priority.high.badgeText", "High badge text."),
        badgeSurface: alias("semantic.color.priority.high.badgeSurface", "High badge surface."),
      },
      medium: {
        accent: alias("semantic.color.priority.medium.accent", "Medium edge."),
        badgeText: alias("semantic.color.priority.medium.badgeText", "Medium badge text."),
        badgeSurface: alias("semantic.color.priority.medium.badgeSurface", "Medium badge surface."),
      },
      low: {
        accent: alias("semantic.color.priority.low.accent", "Low edge."),
        badgeText: alias("semantic.color.priority.low.badgeText", "Low badge text."),
        badgeSurface: alias("semantic.color.priority.low.badgeSurface", "Low badge surface."),
      },
    },
    productLink: {
      surface: alias("semantic.color.shell.canvas", "Product block background."),
      border: alias("semantic.color.productLink.accent", "Product block border."),
      name: alias("semantic.color.shell.text", "Product name."),
      price: alias("semantic.color.productLink.price", "Product price range."),
      action: alias("semantic.color.productLink.action", "View product fill."),
      actionText: alias("semantic.color.analyze.text", "View product label."),
    },
  },
};

const lightColor = {
  $description: "Light theme semantic colors. Anything not listed inherits the dark foundation through the resolver.",
  semantic: {
    color: {
      shell: {
        canvas: paint("#f8fafc", "Light page canvas."),
        surface: paint("#ffffff", "Light section."),
        raised: paint("#f1f5f9", "Light recommendation surface."),
        text: paint("#0f172a", "Light primary text."),
        textSecondary: paint("#334155", "Light secondary text."),
        muted: paint("#475569", "Light muted text. Clears 4.5:1 on canvas, surface, and raised."),
        border: paint("#64748b", "Light border. #94a3b8 on white is about 2.6:1."),
      },
      status: {
        problem: paint("#991b1b", "Light problem text."),
      },
      priority: {
        high: {
          accent: paint("#dc2626", "Light high edge."),
          badgeText: paint("#7f1d1d", "Light high badge text."),
          badgeSurface: paint("#fee2e2", "Light high badge surface."),
        },
        medium: {
          accent: paint("#b45309", "Light medium edge."),
          badgeText: paint("#78350f", "Light medium badge text."),
          badgeSurface: paint("#fef3c7", "Light medium badge surface."),
        },
        low: {
          accent: paint("#2563eb", "Light low edge."),
          badgeText: paint("#1e3a8a", "Light low badge text."),
          badgeSurface: paint("#dbeafe", "Light low badge surface."),
        },
      },
      stage: {
        vpd: paint("#065f46", "Light VPD text."),
        selected: paint("#047857", "Light selected stage border. #10b981 on white fails 3:1."),
      },
      summary: {
        heading: paint("#065f46", "Light summary heading."),
        surface: paint("#d1fae5", "Light summary surface. This is the unused CSS --primary-light."),
      },
      productLink: {
        price: paint("#065f46", "Light price text."),
        accent: paint("#047857", "Light product border."),
      },
      analyze: {
        fill: paint("#047857", "Light analyze fill. 5.48:1 against white, so the white label and the section both clear their bars."),
        text: alias("primitive.color.white", "Light analyze label."),
      },
      focus: paint("#047857", "Light focus color. Proposal, same name as the dark focus token."),
    },
    shadow: {
      focus: shadow("#047857", 1, 0, 0, 0, 3, "Solid 3px focus ring in the light theme."),
    },
  },
};

const resolver = {
  $schema: "https://www.designtokens.org/schemas/2025.10/resolver.json",
  name: "Grow Assist",
  version: "2025.10",
  description:
    "Dark is the default because the stylesheet has no light theme. The light context overrides semantic colors. An empty dark context means the foundation colors stand.",
  sets: {
    foundation: {
      description: "Primitives, dark semantic colors, type roles, and component aliases.",
      sources: [{ $ref: "grow_assist.tokens.json" }],
    },
  },
  modifiers: {
    colorScheme: {
      description: "Light and dark semantic color.",
      default: "dark",
      contexts: {
        dark: [],
        light: [{ $ref: "grow_assist.light.tokens.json" }],
      },
    },
  },
  resolutionOrder: [{ $ref: "#/sets/foundation" }, { $ref: "#/modifiers/colorScheme" }],
};

writeFileSync(join(root, "grow_assist.tokens.json"), JSON.stringify(foundation, null, 2) + "\n");
writeFileSync(join(root, "grow_assist.light.tokens.json"), JSON.stringify(lightColor, null, 2) + "\n");
writeFileSync(join(root, "grow_assist.resolver.json"), JSON.stringify(resolver, null, 2) + "\n");
console.log("wrote tokens");
