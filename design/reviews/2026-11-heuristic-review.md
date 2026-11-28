# Heuristic review, 26 November 2026

Reviewed against one bar. On a phone, a first-time grower goes from an empty form to a prioritized fix list by keyboard or screen reader alone, with 0 serious or critical axe violations.

The page is one screen. Pick a growth stage, paste readings, paste an API key, and read a summary plus two or three recommendations. That flow is what shipped. A key is the only way to get a result until the hosted agent in NES-155 ships. The notes below judge the current page against the bar.

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

The bar is 0 serious or critical axe violations. The only failure is `color-contrast`, impact serious. It fires only when forced colors is active and the color scheme is light, so those results do not meet the bar. The screenshot pixels were not checked against the colors axe computed. Empty pages have 22 nodes. Results pages have 34. Both widths, both environments. Dark forced colors, ordinary dark, and ordinary light have zero violations. Ordinary light looks like ordinary dark, because the stylesheet has no light theme. `local-empty-360-dark.png` and `local-empty-360-light.png` are the same bytes.

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
| Analyze | 0 locally, 1px on the deployed walk | White, the text color. `border: none` means that color does not paint a border | The resting green shadow, unchanged | No `:focus` rule on `.btn-primary`. `local-focus-1280-5-BUTTON-Analyze.png` shows a light edge. This review does not identify which paint produced it. |

## Nielsen

Severity is 0 to 4. 0 is not a problem. 4 is a catastrophe. Kind is Evidence when the row is a measurement or a line of code. Kind is Opinion when the harm depends on the grower hypothesis in the brief.

| Heuristic | Finding | Severity | Kind | Evidence | Fix |
| --- | --- | --- | --- | --- | --- |
| Match between system and the real world | The API key sits between the readings and Analyze. `ready` blocks the request until the field is filled. The placeholder names a vendor. A first visit cannot reach a fix list without a key. Until NES-155, that key is the only way to get a result. The key lives in the model for this page. A reload clears it. | 3 | Evidence | `shell.gleam` lines 36, 79 to 81, and 146 to 161. `local-empty-360-dark.png`. `local-validation-360-dark.png` shows the stage message. The key message is the same paragraph once a stage and readings exist. `client.gleam` has no storage call. | Do not move the key into an advanced area while it is the only way to get a result. Show it inline after Analyze, and only when no key is saved. Say why the key is needed and where to get one. Keep the readings. Remember the key for the next analysis, and keep a way to replace it when the request is rejected. The storage API is unset. Move the field to an advanced area once the hosted agent in NES-155 is live. |
| Help users recognize, diagnose, and recover from errors | "Choose a growth stage.", "Paste a few readings.", and "Paste an API key." render in the recommendations region, under the heading "AI Recommendations". The same is true of "The analysis request failed." and "The request did not reach the server." Nothing points at the control. The paragraph has no `role="alert"` and the region has no live region, so a screen reader is not told. The model keeps the readings when status changes. `apply` replaces `status` and leaves `readings` in place. A reload clears them, because nothing writes them to storage. | 3 | Evidence | `shell.gleam` lines 49 to 60 and 222 to 235. `local-validation-360-dark.png`, `local-server-error-360-dark.png`, `local-offline-360-dark.png`. Accessibility snapshots list the message as a paragraph. `client.gleam` has no storage call. | Put a stage error next to the stage group. Put a readings error next to the readings field. Put a key error next to the key step. Point each control at its message. Put server and offline errors next to Analyze. Announce those errors. Keep the readings on the page, including across a reload if the offline sentence says they are saved. For offline, say the readings are saved and to retry. |
| Visibility of system status | The results view does not move focus to the summary, and it does not announce the results. The accessibility tree lists the summary and the three recommendations as static headings and paragraphs. While status is Loading, Analyze is disabled. The keyboard walks did not press Analyze, so they do not show where focus lands. | 3 | Evidence | `shell.gleam` lines 167 and 238 to 248. The results markup sets no focus and no live region. `local-aria-results-360.txt` has no status role. | After Analyze, move focus to the results and announce them. Do not leave focus on a control that Loading disables. |
| Visibility of system status | The local keyboard walk measures outline width 0 on every stop. Stage cards keep the resting `#334155` border and no shadow. The key field keeps that border and a 10% green ring. The readings rule does set a green border, and the 0.2s transition means the first computed sample is still slate. The analyze button sets `border: none`. Its computed border color is white and the sampled outline width is 0. `local-focus-1280-5-BUTTON-Analyze.png` still shows a light edge. This review does not identify which paint produced that edge. The stylesheet has no `:focus` rule on the stage cards or the analyze button. | 3 | Evidence | Keyboard table above. `styles.css` lines 121 to 145 and 346. `local-keyboard-1280.json`. | A 3px ring on every control, including the stage cards and the analyze button. The ring has to clear 3:1 against the control. Clearing the page is not enough. Keep an outline. Forced colors drop box-shadow. |
| Aesthetic and minimalist design | The analyze label is white on a green gradient. White on `#10b981` is 2.54:1, under the 4.5:1 bar for normal text. The label is 1rem at weight 600, so it is not large text. axe misses it because the background is a gradient. The product link uses the same gradient and white text. | 3 | Evidence | `styles.css` lines 341 to 346 and 555 to 558. Contrast row "white on primary" in `design/tokens/README.md`. `local-empty-1280-dark.png` | One solid fill and a text color that clears 4.5:1, on Analyze and on the product link. The draft uses a light green with dark text in the dark theme, and a dark green with white text in the light theme. |
| Match between system and the real world | Each stage card leads with a VPD range in kPa, then temperature and humidity. The empty region says the recommendations will appear here. On a phone that region is below the form, so the grower meets VPD before any result. | 3 | Evidence for the current order. Hypothesis for the recommended order. | `shell.gleam` lines 103 to 129 and 224 to 227. `local-empty-360-dark.png`. `local-aria-results-360.txt` names each stage button with VPD first. | Lead each stage card with temperature and humidity. Show VPD after those, as a derived value, with one line that explains it. Replace the empty sentence with the first action. |
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

The readings and key labels are wired to their fields. The key is a password field. Priority is a word, "High Impact", plus a color, so the badge is not color alone. At 360 the page is one column and the type stays in the viewport. The keyboard order has no trap. The deployed empty page matches the local build. `apply` keeps the stage, the readings, and the key when status becomes `Problem` or `Ready`.

## Follow-up, 27 November 2026

This pass changes the token draft only. `priv/static/styles.css` is unchanged, so the running page still matches the findings above.

| Finding | Status |
| --- | --- |
| Keyboard focus is missing or under 3:1 on the control. Severity 3, Visibility of system status. | Resolved in the token draft. The indicator is two bands in both themes, so the CSS is one rule. In the dark theme no 8-bit sRGB color clears 3:1 against both the raised card and the analyze fill. The search peaks at 2.61:1. Light can use one dark color. Dark gap `#022c22` is 9.94:1 on the analyze fill `#6ee7b7` and 5.97:1 on the ring `#10b981`. That ring is 7.04:1 on the shell canvas, 5.77:1 on the shell surface, 4.08:1 on the raised card, 7.04:1 on the stage surface and the readings surface, and 5.19:1 on the summary. Light gap `#ffffff` is 5.48:1 on the analyze fill `#047857` and 5.48:1 on the ring. That ring is 5.24:1 on the canvas, 5.48:1 on the shell surface, 5.01:1 on the raised card, 5.24:1 on the stage and readings surfaces, and 4.84:1 on the summary. The checker fails if an adjacent pair misses 3:1. The running stylesheet still has no focus rule on the stage cards or on Analyze. |
| Selected stage is a green border and the name does not change. Severity 2. | The `aria-pressed` fix is still open on the page. Forced colors now have a separate cue in the token note: selected border 4px, resting border 2px, color `Highlight`. Not in the app. |
| Stage card icons are part of the button name. | Guidance added. `.stage-icon` is decorative (`aria-hidden="true"`). The button also contains the VPD, temperature, and humidity, so the accessible name is Seedling, Vegetation, or Flowering only when the button names the stage. Not in the app. The cart emoji row is a different control and is still open. |
| Light forced colors fail `color-contrast`. Severity 2. | Not reproduced on this re-run, and not a token defect. The cause is below. |

`check_tokens.mjs` composites a semantic color with alpha below 1 over the background in its pair. Alpha 0 on shell text scores 1:1 against the canvas and fails. A translucent badge surface is scored over the raised card. A translucent analyze fill is scored over the shell surface, and the product action that shares that fill is scored over the shell canvas. A pair that reaches a semantic color through an alias counts. A translucent semantic color that no pair names throws. The focus proof fails unless the ring is the 2px gap plus the 5px ring in the gap and ring colors, forced colors keep a 3px `Highlight` outline and a 4px `Highlight` selected border, and the stage button's accessible name is Seedling while the card still shows the VPD, temperature, and humidity. The proof page does not open the running app. An axe summary is written only after a capture returns a result.

### Light forced colors, re-run

The capture was `empty` and `results` at 360 and 1280, in dark, light, and forced colors. axe-core 4.14.1 with tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa`, `wcag22aa`. Violations were 0 on every one of those pages, including `local-axe-empty-360-light-forced-colors.json` and `local-axe-results-360-light-forced-colors.json`. The same is true at 1280. Dark forced colors also has 0 violations.

With `forced-colors: active` and a light scheme, computed style on `body`, the stage card, and Analyze is `rgb(0, 0, 0)` on `rgb(255, 255, 255)`. With a dark scheme it is white on black. `forced-color-adjust` stays `auto`. Chromium replaces the stylesheet colors with system colors before axe measures them. Black on white is 21:1. There is no failing pair to retune.

The 26 November table scored the stylesheet inks (`#f1f5f9`, `#cbd5e1`, `#10b981`, `#94a3b8`, and the badge colors) against white. Those hex values live in `priv/static/styles.css`. The page does not load `design/tokens/build`. A light token set would not change this capture until the app imports it, and a real forced-colors mode would still replace those tokens with `Canvas` and `CanvasText`. System colors are not token values. The failure is outside the tokens.

This re-run's full-page bitmaps are a poor picture of that override. `local-empty-360-light-forced-colors.png` is still mostly `#0f172a` and `#1e293b`, with white only in part of the bitmap. A viewport shot of the same mode is white and black. The axe JSON and `getComputedStyle` are the contrast evidence. The full-page file is not.

`color-contrast` is incomplete for 14 nodes on the empty page, in ordinary light and in both forced-colors schemes. Two are the header gradient. Twelve are a pseudo-element. Those nodes are not violations. They are the same in the ordinary light capture, so forced colors did not add them.

## What this review did not verify

The live model. Results screenshots are the client rendering a stubbed 200. The summary text, the three priorities, and the example product are the stub, not a model response.

A real API key. None was typed, sent, or stored.

A real screen reader. The evidence is the accessibility tree and the keyboard, not VoiceOver or NVDA.

Browser zoom. The 200% shots use CSS `zoom`, and the bitmaps are wider than the viewport. `scrollWidth` was not read from the page.

Hover under reduced motion. The resting screenshots match. The lift was not exercised with the preference on.

Zoom, reduced motion, and forced colors at 768. Those three were captured at 360 and 1280.

A session with a grower. The stage-card order is marked Hypothesis. The reset row is marked Opinion. Neither is a usability test.

Where a remembered key is stored. The review says to remember it and to allow a replacement. It does not name a storage API.

Focus after Analyze. The walks did not press Analyze, so the landing focus is unread. The results markup sets no focus.

Streaming. The client has no streaming state to capture.

The product link destination. The stub points at an example address. The deployed capture used the same stub, so the deployed link was not the catalog.

Whether forced-colors pixels match the colors axe computed. On this re-run, `getComputedStyle` and a viewport shot show system black on white in light forced colors, and white on black in dark. The full-page bitmaps still contain the author slate. This review does not treat those bitmaps as the contrast measurement.

A screen reader check of `aria-hidden` on `.stage-icon`. The guidance is written. The running button name still includes the icon and the VPD line. `local-focus-360-0-BUTTON--Seedling-VPD-0-4-0-8-kPa-68-77-F-70-80-.png` is that stop.

The token focus ring on the running page. The app does not import the tokens. `local-focus-1280-5-BUTTON-Analyze.png` is the running Analyze control. The ring in the draft is `local-token-focus-1280-dark.png` and `local-token-focus-1280-light.png`, from a proof page that loads `build/dark.css` and `build/light.css`. Tab landed on Analyze. The computed shadow is `rgb(2, 44, 34) 0px 0px 0px 2px, rgb(16, 185, 129) 0px 0px 0px 5px` in dark, and `rgb(255, 255, 255) 0px 0px 0px 2px, rgb(4, 120, 87) 0px 0px 0px 5px` in light. Forced colors drops the shadow. The outline stays 3px, and the selected stage border is 4px. `local-token-focus-360-light-forced-colors.png`.

Windows High Contrast outside Playwright. The engine here is Chromium with `forcedColors: active`.

Deployed pages. This pass captured local only.

768px forced colors, and browser zoom. The 200% shots are still CSS `zoom`.
