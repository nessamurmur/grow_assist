let chosen = null

export function pageOrigin() {
  if (globalThis.location && globalThis.location.origin) {
    return globalThis.location.origin
  }
  return "http://127.0.0.1:8080"
}

function fileInput() {
  if (!globalThis.document) return null
  return document.getElementById("readings-file")
}

export function snapshotReadingsFile() {
  const input = fileInput()
  const file = input && input.files && input.files[0]
  chosen = file || null
  if (!chosen) return ""
  return chosen.name || "readings.csv"
}

export function clearReadingsFile() {
  chosen = null
  const input = fileInput()
  if (input) input.value = ""
}

export function postCsv(url, stage, apiKey) {
  if (!chosen) snapshotReadingsFile()
  if (!chosen) return Promise.reject(new Error("missing file"))
  const body = new FormData()
  body.append("stage", stage)
  body.append("api_key", apiKey)
  body.append("csv", chosen, chosen.name || "readings.csv")
  return fetch(url, { method: "POST", body }).then(async (response) => {
    return [response.status, await response.text()]
  })
}
