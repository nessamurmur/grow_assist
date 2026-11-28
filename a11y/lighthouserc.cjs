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
