const baseURL = process.env.A11Y_BASE_URL || "http://127.0.0.1:8080"
const chromePath = process.env.CHROME_PATH

module.exports = {
  ci: {
    collect: {
      url: [`${baseURL.replace(/\/$/, "")}/`],
      numberOfRuns: 1,
      ...(chromePath ? { chromePath } : {}),
      settings: {
        onlyCategories: ["accessibility"],
        // GitHub-hosted Ubuntu blocks Chromium's user namespace sandbox.
        chromeFlags: "--no-sandbox --disable-dev-shm-usage",
      },
    },
    assert: {
      assertions: {
        "categories:accessibility": ["error", { minScore: 1 }],
      },
    },
    upload: {
      target: "filesystem",
      outputDir: "./artifacts/lighthouse",
    },
  },
}
