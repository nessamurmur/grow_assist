# Heuristic review, 26 November 2026

Reviewed against one job. A newer home grower, with a tent and sensors and without a reading of the numbers, gets from the landing page to a prioritized fix list on a phone, without help.

The page is one screen. Pick a growth stage, paste readings, paste an API key, and read a summary plus two or three recommendations. That flow is what shipped. The notes below judge it against the job, not against a future account system.

## How this was captured

The local server is the Gleam app from the README, with the client bundle built into `priv/static`. The same script captured the deployed app. The script takes the page address as an argument, so this file does not record a hostname.

States captured: empty, filled form, validation, loading, results, server error, and offline. Widths 360, 768, and 1280. Each of those in light and dark, by emulating `prefers-color-scheme`. Also 200% zoom, reduced motion, and forced colors, at 360 and 1280, in both schemes. The 200% capture sets `documentElement.style.zoom`. It is not the browser's own zoom. The saved bitmaps are wider than the 360px viewport.

axe-core tags on every captured page: `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`. Raw JSON is saved next to the screenshots. Names look like `local-axe-empty-360-dark.json` and `deployed-axe-results-1280-light-forced-colors.json`.

The results state cannot be reached without a key, and the repository has no route that renders `Status.Ready` in the browser. The capture fulfilled `POST /analyze` in the browser with a stub body: a summary, three recommendations, and one product link. The key never left the browser. Those screenshots show the client render of a 200. They are not a live model run.

Playwright accessibility snapshots of each key view, at 360 and 1280 in the dark scheme, are `local-aria-<state>-360.txt` and the 1280 pair, with the same names for `deployed-`. Keyboard walks are `local-keyboard-360.json`, `local-keyboard-1280.json`, and the deployed pair. Focus screenshots are `local-focus-1280-*.png` and `local-focus-360-*.png`.

The deployed empty page at 1280 dark is byte-identical to the local one. The empty accessibility trees match. The results trees match. Findings below apply to both unless a row says otherwise.

## States

| State | Today | Evidence |
| --- | --- | --- |
| Empty | `Status.Waiting`. The results region says the recommendations will appear here. | `shell.gleam` lines 224 to 227. `local-empty-360-dark.png` |
| Filled form | The model holds a stage, readings, and a key. Not a separate status. | `local-filled-360-dark.png` |
| Loading | Button label "Analyzing…" and the region text "Analyzing your tent…". The button is disabled. | `shell.gleam` lines 171 to 175 and 228 to 231. `local-loading-360-dark.png` |
| Streaming | Missing. The client waits for the whole response. | `client/src/client.gleam` lines 50 to 61 |
| Error | `Status.Problem`. Validation, a non-200 body, and a failed fetch all render as one paragraph in the results region. | `shell.gleam` lines 72 to 84 and 232 to 233. `local-validation-360-dark.png`, `local-server-error-360-dark.png` |
| Success | `Status.Ready`. Summary, then recommendation articles, with a product link when the response has one. Captured from the stub. | `local-results-360-dark.png`, `local-aria-results-360.txt` |
| Offline | The fetch rescue string "The request did not reach the server." Same paragraph as any other problem. No offline chrome, and no check of the network before the request. | `client.gleam` lines 55 to 60 and 80. `local-offline-360-dark.png` |

## axe

70 captured pages locally and 70 on the deployed app. 66 of each have zero violations.

The only failure is `color-contrast`, impact serious. It fires only when forced colors is active and the color scheme is light. Empty pages have 22 nodes. Results pages have 34. Both widths, both environments. Dark forced colors, ordinary dark, and ordinary light have zero violations. Ordinary light looks like ordinary dark, because the stylesheet has no light theme. `local-empty-360-dark.png` and `local-empty-360-light.png` are the same bytes.

axe reports the author's dark-theme colors against a white background. The light forced-colors screenshot is `local-empty-360-light-forced-colors.png`. The raw result is `local-axe-empty-360-light-forced-colors.json` and `local-axe-results-360-light-forced-colors.json`. The deployed files with the same suffixes match.

| Rule | Impact | Nodes in one results view | Element | Measured pair |
| --- | --- | --- | --- | --- |
| color-contrast | serious | 12 | Two unselected stage names, the selected stage name, both section headings, the intro, the key field, the summary, three recommendation titles, the product name | `#f1f5f9` on `#ffffff`, 1.09:1 |
| color-contrast | serious | 6 | Tagline, both labels, the three recommendation descriptions | `#cbd5e1` on `#ffffff`, 1.48:1 |
| color-contrast | serious | 5 | Two unselected VPD lines, the selected VPD line, the summary heading, the price | `#10b981` on `#ffffff`, 2.53:1 |
| color-contrast | serious | 6 | Temperature and humidity on the three stage cards | `#94a3b8` on `#ffffff`, 2.56:1 |
| color-contrast | serious | 1 | Key hint | `#94a3b8` on `#ffffff`, 2.56:1 |
| color-contrast | serious | 1 | Footer | `#94a3b8` on `#ffffff`, 2.56:1 |
| color-contrast | serious | 1 | High priority badge | `#fca5a5` on `#ffffff`, 1.89:1 |
| color-contrast | serious | 1 | Medium priority badge | `#fcd34d` on `#ffffff`, 1.44:1 |
| color-contrast | serious | 1 | Low priority badge | `#93c5fd` on `#ffffff`, 1.8:1 |

The node counts above are one results view. Empty views omit the result rows and include the placeholder instead. 360 and 1280 repeat the same nodes. The stylesheet does not set `forced-color-adjust`, and it has no `forced-colors` rules.

axe did not flag the analyze label. The button background is a gradient, and the manual contrast table in `design/tokens/README.md` is the measurement for that pair. White on `#10b981` is 2.54:1.

## Keyboard

Tab order at 360 and 1280, local and deployed.

1. Seedling
2. Vegetation
3. Flowering
4. Readings
5. API key
6. Analyze
7. The document
8. Seedling again

No trap. Shift+Tab from the document returns to the page. The product link is absent in the empty walk. On the results view the link is in the tab order after the form, because it follows the form in the DOM. The results region is the second column on a wide screen and the block under the form on a phone.

Computed focus, from `local-keyboard-1280.json`.

| Stop | Outline width | Border | Shadow | What that means |
| --- | --- | --- | --- | --- |
| Each stage button | 0 | `#334155`, the resting border | none | No focus style. `button.stage-card` sets `appearance: none` at `styles.css` lines 140 to 145 and has no `:focus` rule. Screenshot `local-focus-1280-0-BUTTON--Seedling-VPD-0-4-0-8-kPa-68-77-F-70-80-.png` |
| Readings | 0 at the instant of focus | Resting `#334155` while the 0.2s transition is running | Transparent at that instant | The `:focus` rule at lines 121 to 126 does set a green border. The screenshot `local-focus-1280-3-TEXTAREA-readings.png` shows that border after the transition. The extra ring is 10% green. |
| API key | 0 | Stays `#334155` | `rgba(16, 185, 129, 0.1) 0 0 0 3px` | The later `border` shorthand at lines 128 to 138 wins over the focus `border-color`, so the border never turns green. The ring composites to about 1.17:1. Screenshot `local-focus-1280-4-INPUT-api-key.png` |
| Analyze | 0 locally, 1px on the deployed walk | White, which is the button's text color | The resting green shadow, unchanged | No `:focus` rule on `.btn-primary`. Screenshot `local-focus-1280-5-BUTTON-Analyze.png` |

## Nielsen

Severity is 0 to 4. 0 is not a problem. 4 is a catastrophe. Kind is Evidence when the row is a measurement or a line of code. Kind is Opinion when the harm depends on the grower hypothesis in the brief.

| Heuristic | Finding | Severity | Kind | Evidence | Fix |
| --- | --- | --- | --- | --- | --- |
| Match between system and the real world | The API key is on the main path, between the readings and the only action. Validation refuses to continue until the field is filled. The placeholder names a vendor. A first visit cannot reach a fix list without a key the grower may not have. | 3 | Evidence for the field and the check. Opinion that this blocks the hypothesized grower. The brief says the key becomes an advanced option. | `shell.gleam` lines 79 to 81 and 146 to 161. `local-empty-360-dark.png`. `local-validation-360-dark.png` shows the earlier message. The key message is the same paragraph once a stage and readings exist. | The field can stay while the product is bring-your-own-key. Put the error on the field, and say what the key is for before the grower reaches it. Moving the key off the first path waits on the hosted run the brief describes. The focus ring, the button contrast, and the plain-language stage copy do not. |
| Help users recognize, diagnose, and recover from errors | "Choose a growth stage.", "Paste a few readings.", and "Paste an API key." render in the recommendations region, under the heading "AI Recommendations". The same is true of "The analysis request failed." and "The request did not reach the server." Nothing points at the control. The paragraph has no `role="alert"` and the region has no live region, so a screen reader is not told. | 3 | Evidence | `shell.gleam` lines 222 to 235. `local-validation-360-dark.png`, `local-server-error-360-dark.png`, `local-offline-360-dark.png`. Accessibility snapshots list the message as a paragraph. | Put each message on the control that failed. Move server and network failures to the results region with a live region, and say what to do next. |
| Visibility of system status | The local keyboard walk measures outline width 0 on every stop. Stage cards keep the resting `#334155` border and no shadow. The key field keeps that border and a 10% green ring. The readings rule does set a green border, and the 0.2s transition means the first computed sample is still slate. The analyze button's computed border color is white, so a light edge in its screenshot is the button's own color. The stylesheet draws no focus ring on the stage cards or the analyze button. | 3 | Evidence | Keyboard table above. `styles.css` lines 121 to 145 and 346. `local-keyboard-1280.json`. | A 3px solid ring on every control, including the stage cards and the analyze button. The token draft uses `semantic.shadow.focus` for that ring. Drop `outline: none` on the fields until that ring is in place. |
| Aesthetic and minimalist design | The analyze label is white on a green gradient. White on `#10b981` is 2.54:1, under the 4.5:1 bar for normal text. The label is 1rem at weight 600, so it is not large text. axe misses it because the background is a gradient. | 3 | Evidence | `styles.css` lines 341 to 344. Contrast row "white on primary" in `design/tokens/README.md`. `local-empty-1280-dark.png` | One solid fill and a text color that clears 4.5:1. The draft uses a light green with dark text in the dark theme, and a dark green with white text in the light theme. |
| Match between system and the real world | The first screen leads with VPD ranges in kPa, then °F and RH, and an empty region that says the recommendations will appear here. It does not say what to do first in plain language. On a phone that region is below the form, so the grower meets the jargon before any result. | 3 | Evidence for the copy and the order. Opinion that a new grower cannot act on VPD yet. That reading of the user comes from the brief. | `shell.gleam` lines 96 to 110 and 225 to 227. `local-empty-360-dark.png` | Lead the stage card with the plant stage and one sentence of what the choice is for. Keep the numbers as detail. Replace the empty sentence with the first action. |
| Visibility of system status | Loading is honest, and it is easy to miss. The button and the region both change, the region is below the fold on a phone, and neither is a live region. | 2 | Evidence | `local-loading-360-dark.png`. `shell.gleam` lines 228 to 231. The loading snapshot has no status role. | One live status, next to the button on a phone. |
| Visibility of system status | The selected stage is a green border. The button's accessible name does not change, and there is no pressed state. | 2 | Evidence | `shell.gleam` lines 189 to 194. `local-aria-results-360.txt` lists three buttons with no pressed state. `local-results-360-dark.png` | `aria-pressed` on the selected stage, and keep the border. |
| Recognition rather than recall | The readings placeholder is the only example of a reading. The field accepts any string. The check is "not blank". | 2 | Evidence | `shell.gleam` lines 136 to 138 and 76 to 78. | Show a short sample that stays visible, and name the units the page understands. |
| Consistency and standards | At 768px the stage cards stay in three columns. They become one column only at 640px. The main columns already stack at 968px. | 2 | Evidence | `styles.css` lines 164, 591, and 601. `local-empty-768-dark.png` | Stack the stage cards from the same width the page becomes one column, or earlier. |
| Consistency and standards | At the emulated 200% zoom the title wraps. The empty bitmap is 525px wide and the results bitmap is 688px wide, both wider than the 360px viewport, so the capture shows horizontal overflow. | 2 | Evidence | `local-empty-360-dark-zoom200.png` is 525 by 4403. `local-results-360-dark-zoom200.png` is 688 by 6265. The method is CSS `zoom`, not browser zoom. | Let the title wrap on purpose, and recheck with the browser's own zoom so the overflow is not an artifact of `style.zoom`. |
| Consistency and standards | Emulated light and emulated dark render the same pixels. The stylesheet has no `prefers-color-scheme` rule. | 2 | Evidence | `local-empty-360-dark.png` and `local-empty-360-light.png` are byte-identical. No match for `prefers-color-scheme` in `styles.css`. | Ship the light set in the token draft when a light theme is wanted. Until then, set `color-scheme: dark` so the browser does not assume a light canvas. |
| Consistency and standards | Forced colors with a light scheme is the only axe failure, and it is serious. axe measures the author's light-on-dark colors on white. The analyze button sets `border: none`, so when forced colors strips the green fill the control can lose its shape. Dark forced colors reported no violations. | 2 | Evidence for the axe result and the border. This row does not claim the screenshot text is `#f1f5f9`. | The table in the axe section. `styles.css` line 346. `local-empty-360-light-forced-colors.png` | Give the button a border that forced colors can keep, and recheck the text colors under forced colors rather than trusting the author palette. |
| User control and freedom | "View product" opens a new tab. The link text does not say so. | 2 | Evidence | `shell.gleam` lines 287 to 295. `local-aria-results-360.txt` | Say that the link leaves the page, or open it in the same tab. |
| Aesthetic and minimalist design | Hover lifts the stage card 4px and several controls 2px. There is no `prefers-reduced-motion` rule. The reduced-motion screenshot of the resting page matches the ordinary screenshot, because the motion is on hover. | 2 | Evidence for the CSS. The screenshot does not show the hover. | `styles.css` transforms in the inventory. `local-empty-360-dark-reduced-motion.png` is byte-identical to `local-empty-360-dark.png`. | Under reduced motion, drop the lift and keep color changes. |
| Help and documentation | The only instruction under the form is the key sentence. The footer repeats the three stage names. | 2 | Evidence | `shell.gleam` lines 157 to 160 and 324 to 329. `local-empty-360-dark.png` | One sentence at the top that states the job. Stage, readings, then the first fix. |
| Visibility of system status | The header title is a clipped gradient. At the violet end, `#8b5cf6` on `#0f172a` is 4.22:1. That passes for large text and fails APCA at Lc -31.8. | 2 | Evidence | `styles.css` lines 55 to 58. Contrast row "violet on canvas" in the token note. | Paint the title in the body text color. The token draft does that. |
| Aesthetic and minimalist design | Borders `#334155` on the canvas and on the surface are 1.72:1 and 1.41:1. The high and low priority edges are 2.75:1 and 2.82:1. UI parts need 3:1. | 2 | Evidence | Stylesheet contrast table in the token note. `local-results-1280-dark.png` | Use the border and edge colors from the token draft. |
| Consistency and standards | `.file-upload-*` rules exist. The view has no file input. | 1 | Evidence | `styles.css` from line 249. No file input in `shell.gleam`. | Remove the rules when the upload is designed, or build the control. The brief names CSV upload as the next step. This row does not claim the dead CSS is that feature. |
| Match between system and the real world | The product block starts with a cart emoji that the accessibility tree exposes as its own text. | 1 | Evidence | `shell.gleam` line 281. `local-aria-results-360.txt` | Drop the emoji or mark it decorative. |
| User control and freedom | After a result, the way to start over is to edit the form and press Analyze again. There is no separate reset. | 1 | Opinion | `local-results-1280-dark.png` | A reset is optional on a one-screen form. Add one if testing shows people cannot tell that editing the form is the way back. |

What is working, and should stay.

The readings and key labels are wired to their fields. The key is a password field. Priority is a word, "High Impact", plus a color, so the badge is not color alone. At 360 the page is one column and the type stays in the viewport. The keyboard order has no trap. The deployed empty page matches the local build.

## What this review did not verify

The live model. Results screenshots are the client rendering a stubbed 200. The summary text, the three priorities, and the example product are the stub, not a model response.

A real API key. None was typed, sent, or stored.

A real screen reader. The evidence is the accessibility tree and the keyboard, not VoiceOver or NVDA.

Browser zoom. The 200% shots use CSS `zoom`, and the bitmaps are wider than the viewport. `scrollWidth` was not read from the page.

Hover under reduced motion. The resting screenshots match. The lift was not exercised with the preference on.

Zoom, reduced motion, and forced colors at 768. Those three were captured at 360 and 1280.

A session with a grower. Rows marked Opinion use the brief's hypothesis. They are not a usability test.

Streaming. The client has no streaming state to capture.

The product link destination. The stub points at an example address. The deployed capture used the same stub, so the deployed link was not the catalog.

Whether forced-colors pixels match the colors axe computed. The axe JSON is the contrast evidence. The screenshot is a separate artifact. This review does not reconcile them pixel by pixel.
