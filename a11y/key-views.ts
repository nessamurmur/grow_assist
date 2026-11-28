import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { expect, type Page } from "@playwright/test"

const here = dirname(fileURLToPath(import.meta.url))

export const axeTags = ["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"] as const

export const forcedColorsRuleIds: readonly string[] = []

export const analysisResponse = JSON.stringify({
  summary: "The tent is too humid for flowering.",
  recommendations: [
    {
      title: "Lower the humidity",
      description: "Run a dehumidifier so flowering stays near 40-50% RH.",
      priority: "High",
      product: {
        name: "HYDRONE 5 Dehumidifier",
        url: "https://acinfinity.com/hydroponics-growers/hydrone-5",
        price_range: "$399-499",
      },
    },
    {
      title: "Increase airflow",
      description: "Point a clip fan across the canopy.",
      priority: "Medium",
      product: null,
    },
    {
      title: "Check the leaves",
      description: "Look for spots before the next watering.",
      priority: "Low",
      product: null,
    },
  ],
})

const lightFixture = [
  readFileSync(join(here, "../design/tokens/build/light.css"), "utf8"),
  readFileSync(join(here, "light-remap.css"), "utf8"),
].join("\n")

export type ThemeName = "dark" | "light"

export type KeyView = {
  id: string
  title: string
  pending: boolean
  themes: ThemeName[]
  widths: number[]
  forcedColors: boolean
  prepare: (page: Page) => Promise<() => Promise<void>>
}

async function open(
  page: Page,
  theme: ThemeName,
  width: number,
  forcedColors: boolean,
) {
  await page.setViewportSize({ width, height: width < 768 ? 900 : 1000 })
  await page.emulateMedia({
    colorScheme: forcedColors ? "light" : theme,
    forcedColors: forcedColors ? "active" : "none",
  })
  await page.goto("/")
  if (theme === "light" || forcedColors) {
    await page.addStyleTag({ content: lightFixture })
  }
}

export async function show(
  page: Page,
  theme: ThemeName,
  width: number,
  forcedColors: boolean,
) {
  await open(page, theme, width, forcedColors)
}

async function chooseStage(page: Page, name: string) {
  await page.getByRole("button", { name }).click()
  await expect(page.locator('.stage-card[data-selected="true"]')).toContainText(
    name,
  )
}

async function fillReadings(page: Page) {
  await page.locator("#readings").fill("82 F, 68% RH, VPD 1.4")
}

async function fillKey(page: Page) {
  await page.locator("#api-key").fill("browser-only-test-key")
}

async function analyze(page: Page) {
  await page.getByRole("button", { name: "Analyze", exact: true }).click()
}

const none = async () => {}

export const keyViews: KeyView[] = [
  {
    id: "empty",
    title: "Empty form, Seedling selected",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: true,
    prepare: async (page) => {
      await chooseStage(page, "Seedling")
      return none
    },
  },
  {
    id: "stage-seedling",
    title: "Seedling selected with readings",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      await chooseStage(page, "Seedling")
      await fillReadings(page)
      return none
    },
  },
  {
    id: "stage-vegetation",
    title: "Vegetation selected with readings",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      await chooseStage(page, "Vegetation")
      await fillReadings(page)
      return none
    },
  },
  {
    id: "stage-flowering",
    title: "Flowering selected with readings",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      await chooseStage(page, "Flowering")
      await fillReadings(page)
      return none
    },
  },
  {
    id: "field-error",
    title: "Field error beside the readings field",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      await chooseStage(page, "Seedling")
      await page.locator("#readings").fill("   ")
      await analyze(page)
      await expect(page.locator("#readings-error")).toHaveText(
        "Paste a few readings.",
      )
      await expect(page.locator("#readings")).toHaveValue("   ")
      await expect(page.locator(".analysis-error")).toHaveCount(0)
      return none
    },
  },
  {
    id: "loading",
    title: "Loading after Analyze",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      let release: () => void = () => {}
      const hold = new Promise<void>((resolve) => {
        release = resolve
      })
      await page.route("**/analyze", async (route) => {
        if (route.request().method() !== "POST") {
          await route.fallback()
          return
        }
        await hold
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: analysisResponse,
        })
      })
      await chooseStage(page, "Flowering")
      await fillReadings(page)
      await fillKey(page)
      await analyze(page)
      await expect(page.locator(".analysis-loading")).toHaveText(
        "Analyzing your tent…",
      )
      await expect(
        page.getByRole("button", { name: "Analyzing…" }),
      ).toBeDisabled()
      return async () => {
        release()
        await expect(page.locator("#results-heading")).toBeFocused()
      }
    },
  },
  {
    id: "results",
    title: "Results sorted by priority",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: true,
    prepare: async (page) => {
      await page.route("**/analyze", async (route) => {
        if (route.request().method() !== "POST") {
          await route.fallback()
          return
        }
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: analysisResponse,
        })
      })
      await chooseStage(page, "Flowering")
      await fillReadings(page)
      await fillKey(page)
      await analyze(page)
      const badges = page.locator(".priority-badge")
      await expect(badges).toHaveText([
        "High Impact",
        "Medium Impact",
        "Low Impact",
      ])
      await expect(page.getByRole("link", { name: "View product" })).toHaveAttribute(
        "href",
        "https://acinfinity.com/hydroponics-growers/hydrone-5",
      )
      await expect(page.locator("#results-heading")).toBeFocused()
      await expect(page.locator("#readings")).toHaveValue("82 F, 68% RH, VPD 1.4")
      return none
    },
  },
  {
    id: "server-problem",
    title: "Server problem near Analyze",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      await page.route("**/analyze", async (route) => {
        if (route.request().method() !== "POST") {
          await route.fallback()
          return
        }
        await route.fulfill({
          status: 502,
          contentType: "application/json",
          body: JSON.stringify({ error: "The analysis request failed." }),
        })
      })
      await chooseStage(page, "Vegetation")
      await fillReadings(page)
      await fillKey(page)
      await analyze(page)
      await expect(page.locator(".analysis-error")).toHaveText(
        "The analysis request failed.",
      )
      await expect(page.locator("#readings")).toHaveValue("82 F, 68% RH, VPD 1.4")
      await expect(page.locator("#readings-error")).toHaveCount(0)
      return none
    },
  },
  {
    id: "offline",
    title: "Offline request",
    pending: false,
    themes: ["dark", "light"],
    widths: [360, 1280],
    forcedColors: false,
    prepare: async (page) => {
      await page.route("**/analyze", (route) => route.abort("internetdisconnected"))
      await chooseStage(page, "Vegetation")
      await fillReadings(page)
      await fillKey(page)
      await analyze(page)
      await expect(page.locator(".analysis-error")).toHaveText(
        "The request did not reach the server.",
      )
      await expect(page.locator("#readings")).toHaveValue("82 F, 68% RH, VPD 1.4")
      return none
    },
  },
  {
    id: "api-key",
    title: "API key step",
    pending: true,
    themes: [],
    widths: [],
    forcedColors: false,
    prepare: async () => none,
  },
]
