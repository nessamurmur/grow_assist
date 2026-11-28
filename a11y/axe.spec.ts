import { mkdirSync, writeFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import AxeBuilder from "@axe-core/playwright"
import { expect, test, type Page } from "@playwright/test"
import {
  axeTags,
  forcedColorsRuleIds,
  keyViews,
  show,
  type KeyView,
  type ThemeName,
} from "./key-views.js"

const artifacts = join(dirname(fileURLToPath(import.meta.url)), "artifacts")

function runId(
  view: KeyView,
  theme: ThemeName,
  width: number,
  forcedColors: boolean,
) {
  const scheme = forcedColors ? "light-forced-colors" : theme
  return `${view.id}-${scheme}-${width}`
}

async function gate(
  page: Page,
  view: KeyView,
  theme: ThemeName,
  width: number,
  forcedColors: boolean,
) {
  await show(page, theme, width, forcedColors)
  const cleanup = await view.prepare(page)
  const name = runId(view, theme, width, forcedColors)
  try {
    mkdirSync(join(artifacts, "screenshots"), { recursive: true })
    await page.screenshot({
      path: join(artifacts, "screenshots", `${name}.png`),
      fullPage: true,
    })
    const results = await new AxeBuilder({ page })
      .withTags([...axeTags])
      .analyze()
    mkdirSync(join(artifacts, "axe"), { recursive: true })
    writeFileSync(
      join(artifacts, "axe", `${name}.json`),
      JSON.stringify(results, null, 2),
    )
    const allowed = new Set(forcedColors ? forcedColorsRuleIds : [])
    const blocking = results.violations.filter((violation) => {
      const impact = violation.impact
      const serious = impact === "serious" || impact === "critical"
      return serious && !allowed.has(violation.id)
    })
    const summary = blocking
      .map((violation) => {
        const nodes = violation.nodes
          .slice(0, 3)
          .map((node) => node.target.join(" "))
          .join(", ")
        return `${violation.id} (${violation.impact}) ${nodes}`
      })
      .join("\n")
    expect(summary, `${name} serious or critical axe violations`).toBe("")
  } finally {
    await cleanup()
  }
}

for (const view of keyViews) {
  if (view.pending) {
    test(`${view.title} is PENDING until the just-in-time key step ships`, () => {
      test.skip(true, "PENDING NES-155")
    })
    continue
  }

  for (const theme of view.themes) {
    for (const width of view.widths) {
      test(`${view.title} / ${theme} / ${width}`, async ({ page }) => {
        await gate(page, view, theme, width, false)
      })
    }
  }

  if (view.forcedColors) {
    for (const width of view.widths) {
      test(`${view.title} / light forced colours / ${width}`, async ({ page }) => {
        await gate(page, view, "light", width, true)
      })
    }
  }
}
