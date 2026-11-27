// Capture helper for the heuristic review. The app does not import it.
// Usage: node design/reviews/capture.mjs <label> <baseUrl> [states]
// The label is "local" or "deployed". The URL is an argument so this file
// does not store a host name. CAPTURE_MODULES is the package.json that
// resolves playwright and @axe-core/playwright. CAPTURE_OUT is the directory
// for screenshots and axe JSON. The default is outside this repository, and
// those files are not committed.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const [label, baseUrl, onlyArg] = process.argv.slice(2);
const only = onlyArg ? onlyArg.split(",") : null;
if (!label || !baseUrl) {
  console.error("usage: node design/reviews/capture.mjs <label> <baseUrl> [states]");
  process.exit(1);
}

let chromium;
let AxeBuilder;
try {
  const require = createRequire(process.env.CAPTURE_MODULES ?? "/tmp/ui-review/package.json");
  ({ chromium } = require("playwright"));
  AxeBuilder = require("@axe-core/playwright").default;
} catch (error) {
  console.error("Set CAPTURE_MODULES to a package.json that resolves playwright and @axe-core/playwright.");
  console.error(error.message);
  process.exit(1);
}

const outDir = process.env.CAPTURE_OUT ?? "/opt/cursor/artifacts/ui";
mkdirSync(outDir, { recursive: true });

const fixture = {
  summary: "The tent is too humid for flowering. Dry the air before you change the light.",
  recommendations: [
    {
      title: "Lower the humidity",
      description: "Run a dehumidifier so flowering stays near 40-50% RH. This is the first change.",
      priority: "high",
      product: {
        name: "Example dehumidifier",
        url: "https://example.com/dehumidifier",
        price_range: "$399-499",
      },
    },
    {
      title: "Increase airflow",
      description: "Point a clip fan across the canopy so moist air does not sit on the flowers.",
      priority: "medium",
      product: null,
    },
    {
      title: "Watch leaf temperature",
      description: "Keep the canopy a little cooler than the air so the VPD stays in range.",
      priority: "low",
      product: null,
    },
  ],
};

const widths = [360, 768, 1280];
const schemes = ["light", "dark"];
const states = ["empty", "filled", "validation", "loading", "results", "server-error", "offline"];
const axeTags = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];
const errors = [];

function file(name) {
  return join(outDir, `${label}-${name}`);
}

async function prepare(page, state) {
  if (state === "empty") return;
  const needsForm = ["filled", "loading", "results", "server-error", "offline"].includes(state);
  if (needsForm) {
    await page.getByRole("button", { name: /Flowering/ }).click();
    await page.getByLabel("Readings").fill("82 F, 68% RH, VPD 1.4");
    await page.getByLabel("API key").fill("fixture");
  }
  if (state === "validation") {
    await page.getByRole("button", { name: "Analyze" }).click();
    await page.getByText("Choose a growth stage.").waitFor();
  }
  if (state === "offline") {
    await page.context().setOffline(true);
    await page.getByRole("button", { name: "Analyze" }).click();
    await page.getByText("The request did not reach the server.").waitFor();
  }
}

async function withAnalyzeRoute(page, state, body) {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  await page.route("**/analyze", async (route) => {
    if (state === "loading") await gate;
    const status = state === "server-error" ? 502 : 200;
    const payload = state === "server-error" ? { error: "The analysis request failed." } : body;
    await route.fulfill({
      status,
      contentType: "application/json",
      body: JSON.stringify(payload),
    });
  });
  return release;
}

async function shot(page, name) {
  await page.screenshot({ path: file(`${name}.png`), fullPage: true });
}

async function axe(page, name) {
  const results = await new AxeBuilder({ page }).withTags(axeTags).analyze();
  writeFileSync(file(`axe-${name}.json`), JSON.stringify(results, null, 2));
  return results.violations;
}

async function open(browser, width, scheme, extra = {}) {
  const context = await browser.newContext({
    viewport: { width, height: 900 },
    colorScheme: scheme,
    reducedMotion: extra.reducedMotion,
    forcedColors: extra.forcedColors,
  });
  const page = await context.newPage();
  page.setDefaultTimeout(20000);
  await page.goto(baseUrl, { waitUntil: "domcontentloaded" });
  await page.getByRole("heading", { name: "Grow Assist" }).waitFor();
  if (extra.zoom) {
    await page.evaluate(() => {
      document.documentElement.style.zoom = "200%";
    });
  }
  return { context, page };
}

async function captureState(browser, state, width, scheme, suffix) {
  const name = `${state}-${width}-${scheme}${suffix}`;
  const { context, page } = await open(browser, width, scheme, {
    zoom: suffix === "-zoom200",
    reducedMotion: suffix === "-reduced-motion" ? "reduce" : undefined,
    forcedColors: suffix === "-forced-colors" ? "active" : undefined,
  });
  try {
    let release;
    if (["loading", "results", "server-error"].includes(state)) {
      release = await withAnalyzeRoute(page, state, fixture);
    }
    await prepare(page, state);
    if (state === "loading" || state === "results" || state === "server-error") {
      await page.getByRole("button", { name: "Analyze" }).click();
      if (state === "results") {
        await page.getByRole("heading", { name: "Lower the humidity" }).waitFor();
      } else {
        const expected = state === "loading" ? "Analyzing your tent" : "The analysis request failed.";
        await page.getByText(expected).waitFor();
      }
    }
    await shot(page, name);
    const violations = await axe(page, name);
    if (scheme === "dark" && (width === 360 || width === 1280) && suffix === "") {
      const aria = await page.locator("body").ariaSnapshot();
      writeFileSync(file(`aria-${state}-${width}.txt`), aria);
    }
    if (release) release();
    return violations;
  } finally {
    await context.close();
  }
}

async function keyboardWalk(browser, width) {
  const { context, page } = await open(browser, width, "dark");
  const steps = [];
  try {
    for (let index = 0; index < 12; index += 1) {
      await page.keyboard.press("Tab");
      const info = await page.evaluate(() => {
        const el = document.activeElement;
        const style = getComputedStyle(el);
        const text = (el.innerText || el.getAttribute("aria-label") || el.id || el.tagName).replace(/\s+/g, " ").slice(0, 90);
        return {
          tag: el.tagName,
          id: el.id,
          type: el.getAttribute("type"),
          text,
          outlineStyle: style.outlineStyle,
          outlineWidth: style.outlineWidth,
          borderTopColor: style.borderTopColor,
          boxShadow: style.boxShadow,
        };
      });
      steps.push(info);
      const slug = `${index}-${info.tag}-${(info.id || info.text || "control").replace(/[^a-z0-9]+/gi, "-").slice(0, 40)}`;
      await page.screenshot({ path: file(`focus-${width}-${slug}.png`) });
      const fingerprint = `${info.tag}|${info.id}|${info.text}`;
      if (index > 0 && fingerprint === `${steps[0].tag}|${steps[0].id}|${steps[0].text}`) break;
    }
    await page.keyboard.press("Shift+Tab");
    const back = await page.evaluate(() => {
      const el = document.activeElement;
      return (el.innerText || el.id || el.tagName).replace(/\s+/g, " ").slice(0, 90);
    });
    writeFileSync(file(`keyboard-${width}.json`), JSON.stringify({ steps, shiftTabLandsOn: back }, null, 2));
  } finally {
    await context.close();
  }
}

function proofHtml(css) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Focus proof</title>
  <style>
    ${css}
    body {
      margin: 0;
      background: var(--semantic-color-shell-canvas);
      color: var(--semantic-color-shell-text);
      font: var(--semantic-font-body);
    }
    main {
      background: var(--semantic-color-shell-surface);
      padding: 24px;
    }
    .stage {
      background: var(--component-stage-surface);
      color: var(--component-stage-name);
      border: 2px solid var(--component-stage-border);
      border-radius: 12px;
      padding: 12px;
      margin-bottom: 16px;
    }
    .stage[data-selected="true"] { border-color: var(--component-stage-selected); }
    .analyze {
      background: var(--component-analyze-fill);
      color: var(--component-analyze-text);
      border: none;
      border-radius: 8px;
      padding: 12px 16px;
      font: inherit;
    }
    .stage:focus, .analyze:focus {
      outline: 3px solid var(--component-focus-ring);
      outline-offset: 2px;
      box-shadow: var(--component-focus-gapShadow), var(--component-focus-ringShadow);
    }
    @media (forced-colors: active) {
      .stage:focus, .analyze:focus {
        outline: 3px solid Highlight;
        outline-offset: 2px;
        box-shadow: none;
      }
      .stage[data-selected="true"] {
        border-width: 4px;
        border-color: Highlight;
      }
    }
  </style>
</head>
<body>
  <main>
    <button class="stage" type="button" data-selected="true"><span class="stage-icon" aria-hidden="true">🌱</span> Seedling</button>
    <button class="analyze" type="button">Analyze</button>
  </main>
</body>
</html>`;
}

async function focusProof(browser) {
  const tokenDir = join(dirname(fileURLToPath(import.meta.url)), "..", "tokens", "build");
  const cssFor = {
    dark: readFileSync(join(tokenDir, "dark.css"), "utf8"),
    light: readFileSync(join(tokenDir, "light.css"), "utf8"),
  };
  const samples = [];
  for (const width of [360, 1280]) {
    for (const scheme of ["dark", "light"]) {
      for (const forced of [false, true]) {
        const suffix = forced ? "-forced-colors" : "";
        const { context, page } = await open(browser, width, scheme, {
          forcedColors: forced ? "active" : undefined,
        });
        try {
          await page.setContent(proofHtml(cssFor[scheme]), { waitUntil: "domcontentloaded" });
          await page.keyboard.press("Tab");
          await page.keyboard.press("Tab");
          const info = await page.evaluate(() => {
            const el = document.activeElement;
            const style = getComputedStyle(el);
            const stage = document.querySelector(".stage");
            const stageStyle = getComputedStyle(stage);
            return {
              text: (el.innerText || "").replace(/\s+/g, " ").trim(),
              outlineStyle: style.outlineStyle,
              outlineWidth: style.outlineWidth,
              outlineColor: style.outlineColor,
              boxShadow: style.boxShadow,
              stageBorderWidth: stageStyle.borderTopWidth,
              stageBorderColor: stageStyle.borderTopColor,
            };
          });
          const name = `token-focus-${width}-${scheme}${suffix}`;
          await page.screenshot({ path: file(`${name}.png`) });
          samples.push({ name, ...info });
          if (info.text !== "Analyze") throw new Error(`${name} focused ${info.text}`);
        } finally {
          await context.close();
        }
      }
    }
  }
  writeFileSync(file("token-focus.json"), JSON.stringify(samples, null, 2));
}

function tally(name, violations) {
  return violations.map((violation) => ({
    view: name,
    rule: violation.id,
    impact: violation.impact,
    count: violation.nodes.length,
    targets: violation.nodes.slice(0, 5).map((node) => node.target.join(" ")),
    help: violation.help,
  }));
}

async function main() {
  const browser = await chromium.launch();
  const rows = [];
  try {
    for (const state of states.filter((state) => !only || only.includes(state))) {
      for (const width of widths) {
        for (const scheme of schemes) {
          const name = `${state}-${width}-${scheme}`;
          try {
            const violations = await captureState(browser, state, width, scheme, "");
            rows.push(...tally(`${label}-${name}`, violations));
            console.log("ok", name, "violations", violations.length);
          } catch (error) {
            errors.push({ name, message: String(error).slice(0, 400) });
            console.error("fail", name, error.message);
          }
        }
      }
    }
    for (const state of ["empty", "filled", "results"].filter((state) => !only || only.includes(state))) {
      for (const width of [360, 1280]) {
        for (const scheme of schemes) {
          const name = `${state}-${width}-${scheme}-zoom200`;
          try {
            const violations = await captureState(browser, state, width, scheme, "-zoom200");
            rows.push(...tally(`${label}-${name}`, violations));
            console.log("ok", name);
          } catch (error) {
            errors.push({ name, message: String(error).slice(0, 400) });
            console.error("fail", name, error.message);
          }
        }
      }
    }
    for (const suffix of ["-reduced-motion", "-forced-colors"]) {
      for (const state of ["empty", "results"].filter((state) => !only || only.includes(state))) {
        for (const width of [360, 1280]) {
          for (const scheme of schemes) {
            const name = `${state}-${width}-${scheme}${suffix}`;
            try {
              const violations = await captureState(browser, state, width, scheme, suffix);
              rows.push(...tally(`${label}-${name}`, violations));
              console.log("ok", name);
            } catch (error) {
              errors.push({ name, message: String(error).slice(0, 400) });
              console.error("fail", name, error.message);
            }
          }
        }
      }
    }
    const wantKeyboard = !only || only.includes("keyboard") || only.includes("focus");
    for (const width of wantKeyboard ? [360, 1280] : []) {
      try {
        await keyboardWalk(browser, width);
        console.log("ok keyboard", width);
      } catch (error) {
        errors.push({ name: `keyboard-${width}`, message: String(error).slice(0, 400) });
        console.error("fail keyboard", width, error.message);
      }
    }
    if (!only || only.includes("focus")) {
      try {
        await focusProof(browser);
        console.log("ok focus proof");
      } catch (error) {
        errors.push({ name: "focus-proof", message: String(error).slice(0, 400) });
        console.error("fail focus proof", error.message);
      }
    }
  } finally {
    await browser.close();
  }
  writeFileSync(file("axe-rows.json"), JSON.stringify(rows, null, 2));
  writeFileSync(file("capture-errors.json"), JSON.stringify(errors, null, 2));
  console.log("done", label, "errors", errors.length);
  if (errors.length) process.exitCode = 1;
}

main();
