export function pageOrigin() {
  if (globalThis.location && globalThis.location.origin) {
    return globalThis.location.origin
  }
  return "http://127.0.0.1:8080"
}

export function focusResultsHeading() {
  const heading = document.getElementById("results-heading")
  if (heading instanceof HTMLElement) {
    heading.focus()
  }
}
