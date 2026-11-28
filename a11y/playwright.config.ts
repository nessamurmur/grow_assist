import { defineConfig } from "@playwright/test"

const baseURL = process.env.A11Y_BASE_URL ?? "http://127.0.0.1:8080"

export default defineConfig({
  testDir: ".",
  testMatch: "axe.spec.ts",
  timeout: 90_000,
  fullyParallel: true,
  retries: 0,
  use: {
    baseURL,
    trace: "retain-on-failure",
  },
})
