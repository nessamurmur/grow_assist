# Grow Assist tokens

Draft for review. The running app still paints from `priv/static/styles.css`. These files are not imported by the server or the client.

## Files

`grow_assist.tokens.json` is the foundation. It holds primitives, the dark semantic colors, the type roles, and the component aliases.

`grow_assist.light.tokens.json` overrides the semantic colors that change in the light theme, including both focus bands.

`grow_assist.resolver.json` is the DTCG 2025.10 resolver. The format module has no modes, so light and dark are a modifier rather than two parallel token trees.

`build/dark.css` and `build/light.css` are generated custom properties. They prove the JSON resolves. They are not wired into the app. The repository ignore rule matches any directory named `build`. `.gitignore` has an exception for `design/tokens/build/` so this proof can be committed.

Dark is the default. The shipped stylesheet sets its palette on `:root` and has no `prefers-color-scheme` rule. The resolver's dark context is an empty list, so the foundation colors stand. The light context points at the override file. `resolutionOrder` is the foundation, then the `colorScheme` modifier.

## Tiers

Primitives use generic names such as `color.green.500` and `space.4`.

Semantic tokens name the domain roles below. A semantic color aliases a primitive, such as `semantic.color.priority.high.accent` pointing at `color.red.300`. Primitives that no semantic token references are the recorded stylesheet colors that failed a check, and the spacing, radius, and shadow scales.

Component tokens alias those roles onto the parts of the current page, such as `component.recommendation.description`. The alias is deliberate. A later change can restyle one part without renaming the role.

192 foundation tokens. 92 primitive, 47 semantic, 53 component. The light file has 27 overrides.

## Domain terms

Read from the Gleam modules. Semantic and component names use these words.

| Term | Where | How the tokens use it |
| --- | --- | --- |
| `Stage` with `Seedling`, `Vegetation`, `Flowering` | `shared/src/shared/shell.gleam` lines 10 to 14 | `semantic.color.stage`, `component.stage` |
| `Status` with `Waiting`, `Loading`, `Problem`, `Ready` | `shell.gleam` lines 16 to 21 | `semantic.color.status`, `component.status` |
| `Model` fields `stage`, `readings`, `api_key`, `status` | `shell.gleam` lines 23 to 25 | `readings` and `apiKey` are named from the fields |
| `Msg` `StageChosen`, `ReadingsChanged`, `KeyChanged`, `AnalyzeClicked`, `AnalyzeFinished` | `shell.gleam` lines 27 to 33 | `analyze` is named from `AnalyzeClicked` |
| `Priority` `High`, `Medium`, `Low` | `shared/src/shared/analysis.gleam` lines 12 to 16 | `semantic.color.priority` |
| `ProductLink` with `name`, `url`, `price_range` | `analysis.gleam` lines 18 to 20 | `semantic.color.productLink`, `component.productLink` |
| `Recommendation` with `title`, `description`, `priority`, `product` | `analysis.gleam` lines 22 to 29 | `component.recommendation` |
| `AnalysisResponse` with `summary` and `recommendations` | `analysis.gleam` lines 31 to 33 | `semantic.color.summary`, `component.summary` |

`Ready` has no color of its own. The result is a summary plus recommendations, so the tokens follow those two types. The three stages share one selected color, which matches the stylesheet. The stylesheet does not color Seedling, Vegetation, and Flowering differently.

## Proposals for NJ and the code agents

These names are not types. Confirm them before anyone generates app CSS from this file.

| Token | Why it is a proposal |
| --- | --- |
| `shell` | The view lives in `shell.gleam`. There is no `Shell` type. Header and footer sit under `component.shell` for the same reason. |
| `readings` | `readings` is a `String` field. There is no `Reading` type. |
| `apiKey` | `api_key` is a `String` field. There is no key type. The field stays on the path until the hosted agent in NES-155 ships, then moves to an advanced option. |
| `analyze` | Named from the `AnalyzeClicked` message. The button is not a type. |
| `focus` | The domain has no word for the keyboard indicator. |
| `stage.vpd` | VPD is copy on the stage card and in `priv/system_prompt.txt`. It is not a type. The review treats it as a derived value. |

## Inventory

Design values in `priv/static/styles.css`. Counts are declarations, not selectors. A grouped selector is one declaration. A shorthand counts once for each distinct length in that declaration. A bare `0` is not the same row as `0px`. `var()` is expanded through the `:root` custom properties, so a color counts at the custom property and again at each use. `font: inherit` and `font-family: inherit` stay in the font-family row. `color: inherit` on `button.stage-card` is the color row. Keywords that turn a property off, such as `border: none`, `outline: none`, and `appearance: none`, are not rows. An `outline` width is filed under border width.


### border-width

| Value | Count | Where |
| --- | --- | --- |
| `2px` | 8 | textarea; input[type="password"], input[type="text"]; .stage-card; .file-upload-label; .file-input:focus + .file-upload-label; .response-container; .recommendation-card; .product-recommendation |
| `1px` | 6 | section; .file-name-display.has-file; .priority-badge.priority-high; .priority-badge.priority-medium; .priority-badge.priority-low; footer |
| `4px` | 4 | .analysis-summary; .recommendation-card.priority-high; .recommendation-card.priority-medium; .recommendation-card.priority-low |

### breakpoint

| Value | Count | Where |
| --- | --- | --- |
| `@media (max-width: 640px)` | 1 | @media (max-width: 640px) |
| `@media (max-width: 968px)` | 1 | @media (max-width: 968px) |

### color

| Value | Count | Where |
| --- | --- | --- |
| `#10b981` | 18 | :root; header h1; textarea:focus, input:focus; .stage-card::before; .stage-card:hover; .stage-card[data-selected="true"]; .stage-vpd; .file-upload-label:hover; .file-input:focus + .file-upload-label; .file-name-display.has-file; .btn-primary; .analysis-summary; .analysis-summary h3; .product-recommendation; .product-price; .product-link; .product-link:hover |
| `#334155` | 14 | :root; section; textarea; input[type="password"], input[type="text"]; .stage-card; .file-upload-label; .file-name-display; .response-container; .recommendation-card; footer; ::-webkit-scrollbar-thumb; ::-webkit-scrollbar-thumb:hover |
| `#f1f5f9` | 11 | :root; body; section h2; textarea; input[type="password"], input[type="text"]; .stage-name; .file-upload-title; .response-container .ai-message; .analysis-summary p; .recommendation-header h4; .product-details strong |
| `#0f172a` | 9 | :root; body; textarea; input[type="password"], input[type="text"]; .stage-card; .file-upload-label; .response-container; .product-recommendation; ::-webkit-scrollbar-track |
| `#94a3b8` | 9 | :root; textarea::placeholder; .stage-details; .file-upload-hint; .file-name-display; .file-info; small; .response-container .placeholder; footer |
| `#cbd5e1` | 5 | :root; header p; label; .analysis-loading; .recommendation-description |
| `#059669` | 4 | :root; .btn-primary; .product-link; .product-link:hover |
| `#8b5cf6` | 3 | :root; header h1; .stage-card::before |
| `rgba(0, 0, 0, 0.3)` | 3 | :root; section; .recommendation-card:hover |
| `rgba(16, 185, 129, 0.1)` | 3 | textarea:focus, input:focus; .file-name-display.has-file; .analysis-summary |
| `#1e293b` | 2 | :root; section |
| `#fca5a5` | 2 | .analysis-error; .priority-badge.priority-high |
| `rgba(16, 185, 129, 0.2)` | 2 | .stage-card:hover; .stage-card[data-selected="true"] |
| `rgba(16, 185, 129, 0.3)` | 2 | .btn-primary; .product-link |
| `rgba(16, 185, 129, 0.4)` | 2 | .btn-primary:hover; .product-link:hover |
| `white` | 2 | .btn-primary; .product-link |
| `#3b82f6` | 1 | .recommendation-card.priority-low |
| `#93c5fd` | 1 | .priority-badge.priority-low |
| `#d1fae5` | 1 | :root |
| `#ef4444` | 1 | .recommendation-card.priority-high |
| `#f59e0b` | 1 | .recommendation-card.priority-medium |
| `#fcd34d` | 1 | .priority-badge.priority-medium |
| `inherit` | 1 | button.stage-card |
| `rgba(139, 92, 246, 0.05)` | 1 | .file-upload-label:hover |
| `rgba(139, 92, 246, 0.1)` | 1 | .analysis-summary |
| `rgba(16, 185, 129, 0.05)` | 1 | .file-upload-label:hover |
| `rgba(239, 68, 68, 0.2)` | 1 | .priority-badge.priority-high |
| `rgba(239, 68, 68, 0.3)` | 1 | .priority-badge.priority-high |
| `rgba(245, 158, 11, 0.2)` | 1 | .priority-badge.priority-medium |
| `rgba(245, 158, 11, 0.3)` | 1 | .priority-badge.priority-medium |
| `rgba(59, 130, 246, 0.2)` | 1 | .priority-badge.priority-low |
| `rgba(59, 130, 246, 0.3)` | 1 | .priority-badge.priority-low |
| `transparent` | 1 | header h1 |

### custom-property

| Value | Count | Where |
| --- | --- | --- |
| `--background: #0f172a` | 1 | :root |
| `--border: #334155` | 1 | :root |
| `--primary-hover: #059669` | 1 | :root |
| `--primary-light: #d1fae5` | 1 | :root |
| `--primary: #10b981` | 1 | :root |
| `--radius: 12px` | 1 | :root |
| `--secondary: #8b5cf6` | 1 | :root |
| `--shadow: rgba(0, 0, 0, 0.3)` | 1 | :root |
| `--spacing: 1.5rem` | 1 | :root |
| `--surface-hover: #334155` | 1 | :root |
| `--surface: #1e293b` | 1 | :root |
| `--text-muted: #94a3b8` | 1 | :root |
| `--text-primary: #f1f5f9` | 1 | :root |
| `--text-secondary: #cbd5e1` | 1 | :root |

### font-family

| Value | Count | Where |
| --- | --- | --- |
| `inherit` | 3 | textarea; input[type="password"], input[type="text"]; button.stage-card |
| `-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif` | 1 | body |

### font-size

| Value | Count | Where |
| --- | --- | --- |
| `1.1rem` | 5 | header p; .stage-name; .file-upload-title; .analysis-summary h3; @640 .recommendation-header h4 |
| `0.9rem` | 4 | .file-upload-hint; .file-name-display; .product-price; footer |
| `1rem` | 4 | textarea; input[type="password"], input[type="text"]; .btn-primary; .product-details strong |
| `0.85rem` | 3 | .stage-vpd; .file-info; small |
| `2.5rem` | 3 | @968 header h1; @640 .stage-icon; @640 .file-upload-icon |
| `3rem` | 3 | header h1; .stage-icon; .file-upload-icon |
| `0.95rem` | 2 | label; .product-link |
| `2rem` | 2 | .product-icon; @640 header h1 |
| `0.75rem` | 1 | .priority-badge |
| `0.8rem` | 1 | .stage-details |
| `1.25rem` | 1 | @640 section h2 |
| `1.2rem` | 1 | .recommendation-header h4 |
| `1.5rem` | 1 | section h2 |

### font-weight

| Value | Count | Where |
| --- | --- | --- |
| `600` | 9 | section h2; .stage-name; .file-upload-title; .btn-primary; .analysis-summary h3; .recommendation-header h4; .priority-badge; .product-price; .product-link |
| `500` | 2 | label; .stage-vpd |
| `700` | 1 | header h1 |

### line-height

| Value | Count | Where |
| --- | --- | --- |
| `1.7` | 2 | .analysis-summary p; .recommendation-description |
| `1.6` | 1 | body |
| `1.8` | 1 | .response-container .ai-message |

### other

| Value | Count | Where |
| --- | --- | --- |
| `transition: all 0.3s ease` | 6 | .stage-card; .file-upload-label; .file-name-display; .btn-primary; .recommendation-card; .product-link |
| `width: 100%` | 5 | textarea; input[type="password"], input[type="text"]; button.stage-card; .btn-primary; @640 .product-link |
| `transform: translateY(-2px)` | 4 | .file-upload-label:hover; .btn-primary:hover; .recommendation-card:hover; .product-link:hover |
| `min-height: 100vh` | 2 | body; .container |
| `opacity: 0` | 2 | .stage-card::before; .file-input |
| `transform: translateY(0)` | 2 | .btn-primary:active; .product-link:active |
| `height: 0.1px` | 1 | .file-input |
| `letter-spacing: 0.5px` | 1 | .priority-badge |
| `max-width: 1200px` | 1 | .container |
| `min-height: 200px` | 1 | .response-container |
| `min-width: 200px` | 1 | .product-info |
| `min-width: unset` | 1 | @640 .product-info |
| `opacity: 0.1` | 1 | .stage-card[data-selected="true"]::before |
| `opacity: 0.6` | 1 | .btn-primary:disabled |
| `outline-offset: 2px` | 1 | .file-input:focus + .file-upload-label |
| `transform: none` | 1 | .btn-primary:disabled |
| `transform: translateY(-4px)` | 1 | .stage-card:hover |
| `transition: all 0.2s ease` | 1 | textarea |
| `transition: filter 0.3s ease` | 1 | .stage-icon |
| `transition: opacity 0.3s ease` | 1 | .stage-card::before |
| `width: 0.1px` | 1 | .file-input |
| `width: 10px` | 1 | ::-webkit-scrollbar |
| `z-index: -1` | 1 | .file-input |
| `z-index: 0` | 1 | .stage-card::before |
| `z-index: 1` | 1 | .stage-card > * |

### radius

| Value | Count | Where |
| --- | --- | --- |
| `8px` | 6 | textarea; input[type="password"], input[type="text"]; .file-name-display; .btn-primary; .response-container; .product-link |
| `12px` | 5 | section; .stage-card; .file-upload-label; .analysis-summary; .recommendation-card |
| `10px` | 1 | .product-recommendation |
| `20px` | 1 | .priority-badge |
| `5px` | 1 | ::-webkit-scrollbar-thumb |

### shadow

| Value | Count | Where |
| --- | --- | --- |
| `0 4px 12px rgba(16, 185, 129, 0.3)` | 2 | .btn-primary; .product-link |
| `0 6px 20px rgba(16, 185, 129, 0.4)` | 2 | .btn-primary:hover; .product-link:hover |
| `0 0 0 3px rgba(16, 185, 129, 0.1)` | 1 | textarea:focus, input:focus |
| `0 0 0 3px rgba(16, 185, 129, 0.2)` | 1 | .stage-card[data-selected="true"] |
| `0 10px 30px rgba(0, 0, 0, 0.3)` | 1 | section |
| `0 8px 20px rgba(0, 0, 0, 0.3)` | 1 | .recommendation-card:hover |
| `0 8px 20px rgba(16, 185, 129, 0.2)` | 1 | .stage-card:hover |

### spacing

| Value | Count | Where |
| --- | --- | --- |
| `1rem` | 21 | textarea; input[type="password"], input[type="text"]; .analysis-loading; .growth-stage-selector; .stage-card; .file-name-display; .btn-primary; .response-container .placeholder; .response-container p; .recommendation-header; .recommendation-description; .product-recommendation; .product-info; @640 .container; @640 header; @640 section; @640 .stage-card; @640 .file-upload-label; @640 .product-recommendation |
| `0` | 13 | *; .container; header; .stage-card::before; .response-container p:last-child; .analysis-summary p; .recommendation-header h4; footer; @640 header |
| `0.75rem` | 11 | .growth-stage-selector; .stage-icon; .stage-vpd; .file-upload-wrapper; .file-name-display; .analysis-summary h3; .priority-badge; .product-link; @640 .growth-stage-selector; @640 .recommendation-header |
| `1.5rem` | 10 | section; section h2; .form-group; .stage-card; .file-upload-label; .response-container; .analysis-summary; .recommendation-card; .product-link |
| `2rem` | 7 | .container; header; main; .btn-primary; .analysis-summary; footer; @640 header |
| `0.5rem` | 6 | header h1; label; .stage-name; .file-info; small; .product-link |
| `1.25rem` | 5 | .recommendations-list; .product-recommendation; @640 .stage-card; @640 .file-upload-label; @640 .recommendation-card |
| `3rem` | 4 | header; main; .analysis-loading; .response-container .placeholder |
| `0.25rem` | 3 | .stage-details; .file-upload-text; .product-details |
| `0.35rem` | 1 | .priority-badge |

## Scales

Space is a 4px step, named by the 4px multiplier, stored in rem. `space.0` is 0. `space.1` is 0.25rem. `space.2` is 0.5rem. `space.3` is 0.75rem. `space.4` is 1rem. `space.5` is 1.25rem. `space.6` is 1.5rem, which is the current `--spacing`. `space.8` is 2rem. `space.12` is 3rem.

Type is named in px at a 16px root and stored in rem. 12, 14, 16, 18, 20, 24, 32, 40, 48.

Weights are 400, 500, 600, and 700. 400 is the user-agent initial. The stylesheet never sets it.

Leading is 1.6 for the page and 1.75 for prose.

Radius is 4px, 8px, 12px, and a 999px pill.

Shadows are rest `0 4px 12px`, hover `0 8px 20px`, and overlay `0 10px 30px`. The stylesheet tints the button, product link, and stage hover shadows green. This draft uses 30% black for rest, hover, and overlay, the same ink as the section shadow. The focus indicator is two solid bands, not one 3px shadow. See Focus ring.

Border widths stay 1px, 2px, and 4px. Durations stay 200ms and 300ms. Easing is the CSS keyword `ease`, written as `cubic-bezier(0.25, 0.1, 0.25, 1)`.

## Merges

| From | To | Why |
| --- | --- | --- |
| 0.8rem, 0.85rem, 0.9rem | 0.875rem (`font.size.14`) | Three sizes within a tenth of a rem, used for VPD, hints, price, and the footer. |
| 0.95rem | 1rem (`font.size.16`) | Labels and the product link sit next to 1rem body text. |
| 1.1rem | 1.125rem (`font.size.18`) | Tagline, stage name, and summary heading. |
| 1.2rem | 1.25rem (`font.size.20`) | Recommendation title. The compact section heading is already 1.25rem. |
| 1.7 and 1.8 line height | 1.75 (`font.leading.prose`) | Summary, recommendation, and the unused `.ai-message` rule. |
| 0.35rem badge padding | 0.5rem (`space.2`) | The only off-scale space. Rounded up so the priority label does not get tighter. |
| 5px scrollbar radius | 4px (`radius.1`) | One scrollbar thumb. |
| 10px product radius | 12px (`radius.3`) | The product block sits inside a 12px card. |
| 20px badge radius | 999px (`radius.full`) | The badge is a pill. 20px already clips it to a pill at this height. |
| Button hover `0 6px 20px` and stage hover `0 8px 20px` | hover `0 8px 20px` at 30% black | Three hover shadows. One offset, and the green tint is dropped. |
| Green-tinted `0 4px 12px` on the button and the product link | rest `0 4px 12px` at 30% black | Same offset the stylesheet uses. The glow color is not a second system. |

## One-offs kept

| Value | Why it stays |
| --- | --- |
| 0.75rem (`font.size.12`) | Uppercase priority badge only. |
| 2.5rem (`font.size.40`) | Title size between the phone 2rem and the desktop 3rem. The stacked layout already uses it. |
| 640px and 968px | The compact and stack breakpoints. They are not 768 or 1024, and merging them would change the layout. |
| 1200px shell max, 200px response min, 200px product min | Layout constants, not a spacing step. |
| 2px lift and 4px stage lift | The selected stage lifts further than a button. |
| 0.5px badge tracking | The only letter spacing in the file. |

## Left out of the semantic layer

`opacity: 0.6` on the disabled analyze button. Inactive controls are exempt from the contrast ratio, and the loading copy lives on `status.loading`.

`width: 0.1px` and `height: 0.1px` on `.file-input`. The view in `shell.gleam` has no file input. The file-upload rules are inventoried and not tokenized.

The header gradient from `#10b981` to `#8b5cf6`. Violet `#8b5cf6` and `#c4b5fd` are recorded primitives. No semantic token references them. The title uses shell text.

`#059669`, `#ef4444`, `#f87171`, `#3b82f6`, and `#60a5fa` are recorded because the stylesheet uses them. They fail the checks below, so semantic tokens point at the passing step instead.

## Palette

NJ kept Grow Assist's dark slate and emerald palette, with the contrast fixes in this draft. The body font stays `primitive.font.family.system`. The title uses shell text. Violet `#8b5cf6` and `#c4b5fd` stay recorded primitives because the stylesheet gradient uses them. No semantic color references them. The running stylesheet is still dark only. Light is the resolver override for when a light theme ships.

## Contrast of the current stylesheet

WCAG 2.2 relative luminance. Normal text needs 4.5:1. Large text and UI parts need 3:1. APCA Lc is SAPC 0.0.98G-4g from `apca-w3` 0.1.9. Positive Lc is dark text on a light background. The second-opinion bars used here are absolute Lc 75 for body text and 45 for UI. Those bars are not a WCAG criterion. The black-on-white self-check is 21:1 and Lc 106.04.

The header gradient is scored at the violet end only. The 10% focus ring is the composite of that green over `#1e293b`, which is `#1d3742`.

| Pair | Kind | Bar | Ratio | Lc | Result |
| --- | --- | --- | --- | --- | --- |
| white on primary | text | 4.5 | 2.54 | -54.2 | fail |
| white on primary hover | text | 4.5 | 3.77 | -70.1 | fail |
| muted on raised | text | 4.5 | 4.04 | -41.9 | fail |
| muted on canvas | text | 4.5 | 6.96 | -50.6 | pass |
| secondary text on canvas | text | 4.5 | 12.02 | -79.3 | pass |
| primary text on canvas | text | 4.5 | 16.30 | -99.8 | pass |
| violet on canvas, large title | large | 3 | 4.22 | -31.8 | pass |
| violet on canvas, normal | text | 4.5 | 4.22 | -31.8 | fail |
| green text on canvas | text | 4.5 | 7.04 | -51.8 | pass |
| error on canvas | text | 4.5 | 9.41 | -65.4 | pass |
| border on canvas | ui | 3 | 1.72 | -7.4 | fail |
| border on surface | ui | 3 | 1.41 | 0.0 | fail |
| high edge on raised | ui | 3 | 2.75 | -28.0 | fail |
| medium edge on raised | ui | 3 | 4.82 | -50.6 | pass |
| low edge on raised | ui | 3 | 2.82 | -27.9 | fail |
| focus ring 10 percent over surface | ui | 3 | 1.17 | 0.0 | fail |

Nine pairs fail. The token draft answers them as follows.

White on `#10b981` is 2.54:1, and white on `#059669` is 3.77:1. The dark analyze button uses `#6ee7b7` with `#022c22` text. The light button uses `#047857` with white text. Both clear 4.5:1 against the button and against the surface behind it.

`#94a3b8` on `#334155` is 4.04:1. Dark muted text and the dark border move to `#a8b3c4`.

`#8b5cf6` on `#0f172a` is 4.22:1. The title is 2rem or larger, so it passes as large text and fails as normal text. APCA Lc is -31.8. The draft drops the gradient and sets the title in shell text.

`#334155` on `#0f172a` is 1.72:1, and on `#1e293b` it is 1.41:1. Borders use the muted ink, which clears 3:1.

`#ef4444` on `#334155` is 2.75:1. The dark high edge is `#fca5a5`. `#3b82f6` on `#334155` is 2.82:1. The dark low edge is `#93c5fd`. The medium edge `#f59e0b` already passes and stays.

The 10% focus ring composites to 1.17:1. A later single solid ring in `#10b981` still misses the analyze fill. See Focus ring.

Badge surfaces become solid colors. The stylesheet uses a 20% wash. Dark problem text moves from `#fca5a5` to `#fecaca` so the APCA body bar clears. `#fca5a5` already passes WCAG.

## Contrast of the tokens

92 semantic text, large-text, and UI pairs. 0 WCAG failures. Every UI pair clears absolute Lc 45 except the dark focus ring on the raised card, which is Lc -43.0 at 4.08:1.

| Theme | Pair | Kind | Bar | Ratio | Lc | Result |
| --- | --- | --- | --- | --- | --- | --- |
| dark | shell text on canvas | text | 4.5 | 16.30 | -99.8 | pass |
| dark | shell text on surface | text | 4.5 | 13.35 | -97.3 | pass |
| dark | shell text on raised | text | 4.5 | 9.45 | -91.1 | pass |
| dark | secondary on canvas | text | 4.5 | 14.48 | -91.4 | pass |
| dark | secondary on surface | text | 4.5 | 11.87 | -88.9 | pass |
| dark | secondary on raised | text | 4.5 | 8.40 | -82.7 | pass |
| dark | muted on canvas | text | 4.5 | 8.42 | -59.6 | pass |
| dark | muted on surface | text | 4.5 | 6.90 | -57.1 | pass |
| dark | muted on raised | text | 4.5 | 4.89 | -50.8 | pass |
| dark | waiting on canvas | text | 4.5 | 14.48 | -91.4 | pass |
| dark | loading on canvas | text | 4.5 | 14.48 | -91.4 | pass |
| dark | problem on canvas | text | 4.5 | 12.34 | -80.9 | pass |
| dark | VPD on stage surface | text | 4.5 | 11.71 | -78.0 | pass |
| dark | summary heading on summary | text | 4.5 | 10.27 | -84.6 | pass |
| dark | summary text on summary | text | 4.5 | 12.02 | -95.6 | pass |
| dark | price on product surface | text | 4.5 | 11.71 | -78.0 | pass |
| dark | analyze label on fill | text | 4.5 | 9.94 | 75.4 | pass |
| dark | product action label on fill | text | 4.5 | 9.94 | 75.4 | pass |
| dark | high badge | text | 4.5 | 10.28 | -78.5 | pass |
| dark | medium badge | text | 4.5 | 11.04 | -87.3 | pass |
| dark | low badge | text | 4.5 | 10.05 | -79.2 | pass |
| dark | stage detail on stage | text | 4.5 | 14.48 | -91.4 | pass |
| dark | recommendation title | text | 4.5 | 9.45 | -91.1 | pass |
| dark | recommendation description | text | 4.5 | 8.40 | -82.7 | pass |
| dark | readings text | text | 4.5 | 16.30 | -99.8 | pass |
| dark | readings placeholder | text | 4.5 | 14.48 | -91.4 | pass |
| dark | api key hint on surface | text | 4.5 | 11.87 | -88.9 | pass |
| dark | footer on canvas | text | 4.5 | 8.42 | -59.6 | pass |
| dark | tagline on canvas | text | 4.5 | 14.48 | -91.4 | pass |
| dark | border on canvas | ui | 3 | 8.42 | -59.6 | pass |
| dark | border on surface | ui | 3 | 6.90 | -57.1 | pass |
| dark | border on raised | ui | 3 | 4.89 | -50.8 | pass |
| dark | focus ring on shell canvas | ui | 3 | 7.04 | -51.8 | pass |
| dark | focus ring on shell surface | ui | 3 | 5.77 | -49.3 | pass |
| dark | focus ring on shell raised | ui | 3 | 4.08 | -43.0 | pass |
| dark | focus ring on stage surface | ui | 3 | 7.04 | -51.8 | pass |
| dark | focus ring on readings surface | ui | 3 | 7.04 | -51.8 | pass |
| dark | focus ring on summary surface | ui | 3 | 5.19 | -47.6 | pass |
| dark | focus gap on analyze fill | ui | 3 | 9.94 | 75.4 | pass |
| dark | focus gap on focus ring | ui | 3 | 5.97 | 50.7 | pass |
| dark | selected stage on canvas | ui | 3 | 7.04 | -51.8 | pass |
| dark | high accent on raised | ui | 3 | 5.46 | -56.7 | pass |
| dark | medium accent on raised | ui | 3 | 4.82 | -50.6 | pass |
| dark | low accent on raised | ui | 3 | 5.74 | -59.4 | pass |
| dark | product border on canvas | ui | 3 | 7.04 | -51.8 | pass |
| dark | analyze fill on surface | ui | 3 | 9.60 | -75.5 | pass |
| light | shell text on canvas | text | 4.5 | 17.06 | 101.4 | pass |
| light | shell text on surface | text | 4.5 | 17.85 | 104.6 | pass |
| light | shell text on raised | text | 4.5 | 16.30 | 98.3 | pass |
| light | secondary on canvas | text | 4.5 | 9.90 | 90.9 | pass |
| light | secondary on surface | text | 4.5 | 10.35 | 94.0 | pass |
| light | secondary on raised | text | 4.5 | 9.45 | 87.7 | pass |
| light | muted on canvas | text | 4.5 | 7.24 | 83.2 | pass |
| light | muted on surface | text | 4.5 | 7.58 | 86.3 | pass |
| light | muted on raised | text | 4.5 | 6.92 | 80.0 | pass |
| light | waiting on canvas | text | 4.5 | 9.90 | 90.9 | pass |
| light | loading on canvas | text | 4.5 | 9.90 | 90.9 | pass |
| light | problem on canvas | text | 4.5 | 7.94 | 83.9 | pass |
| light | VPD on stage surface | text | 4.5 | 7.34 | 83.1 | pass |
| light | summary heading on summary | text | 4.5 | 6.78 | 77.7 | pass |
| light | summary text on summary | text | 4.5 | 15.74 | 96.0 | pass |
| light | price on product surface | text | 4.5 | 7.34 | 83.1 | pass |
| light | analyze label on fill | text | 4.5 | 5.48 | -82.2 | pass |
| light | product action label on fill | text | 4.5 | 5.48 | -82.2 | pass |
| light | high badge | text | 4.5 | 8.20 | 78.6 | pass |
| light | medium badge | text | 4.5 | 8.15 | 82.9 | pass |
| light | low badge | text | 4.5 | 8.49 | 80.2 | pass |
| light | stage detail on stage | text | 4.5 | 9.90 | 90.9 | pass |
| light | recommendation title | text | 4.5 | 16.30 | 98.3 | pass |
| light | recommendation description | text | 4.5 | 9.45 | 87.7 | pass |
| light | readings text | text | 4.5 | 17.06 | 101.4 | pass |
| light | readings placeholder | text | 4.5 | 9.90 | 90.9 | pass |
| light | api key hint on surface | text | 4.5 | 10.35 | 94.0 | pass |
| light | footer on canvas | text | 4.5 | 7.24 | 83.2 | pass |
| light | tagline on canvas | text | 4.5 | 9.90 | 90.9 | pass |
| light | border on canvas | ui | 3 | 4.55 | 69.9 | pass |
| light | border on surface | ui | 3 | 4.76 | 73.0 | pass |
| light | border on raised | ui | 3 | 4.34 | 66.7 | pass |
| light | focus ring on shell canvas | ui | 3 | 5.24 | 73.7 | pass |
| light | focus ring on shell surface | ui | 3 | 5.48 | 76.8 | pass |
| light | focus ring on shell raised | ui | 3 | 5.01 | 70.5 | pass |
| light | focus ring on stage surface | ui | 3 | 5.24 | 73.7 | pass |
| light | focus ring on readings surface | ui | 3 | 5.24 | 73.7 | pass |
| light | focus ring on summary surface | ui | 3 | 4.84 | 68.3 | pass |
| light | focus gap on analyze fill | ui | 3 | 5.48 | -82.2 | pass |
| light | focus gap on focus ring | ui | 3 | 5.48 | -82.2 | pass |
| light | selected stage on canvas | ui | 3 | 5.24 | 73.7 | pass |
| light | high accent on raised | ui | 3 | 4.41 | 65.3 | pass |
| light | medium accent on raised | ui | 3 | 4.58 | 67.7 | pass |
| light | low accent on raised | ui | 3 | 4.72 | 68.6 | pass |
| light | product border on canvas | ui | 3 | 5.24 | 73.7 | pass |
| light | analyze fill on surface | ui | 3 | 5.48 | 76.8 | pass |

Four dark text pairs still sit under the APCA body bar of 75. They pass WCAG.

| Pair | Ratio | Lc |
| --- | --- | --- |
| Muted on canvas | 8.42 | -59.6 |
| Muted on surface | 6.90 | -57.1 |
| Muted on raised | 4.89 | -50.8 |
| Footer on canvas | 8.42 | -59.6 |

The footer uses the muted ink. Stage detail, the readings placeholder, and the key hint use secondary text, which clears the APCA body bar. If the footer must clear it too, point `component.shell.footer` at `semantic.color.shell.textSecondary`.

## Focus ring

One color cannot be the dark focus indicator. `#10b981` on the shell canvas is 7.04:1, on the shell surface 5.77:1, and on the raised card 4.08:1. The same green on the analyze fill `#6ee7b7` is 1.66:1. No 8-bit sRGB color reaches 3:1 against both `#334155` and `#6ee7b7`. The search peaks at 2.61:1. The light analyze fill is `#047857`, which was the whole light focus color, so that pair was 1:1.

The indicator is two solid bands. The gap is the inner 2px. It touches the analyze fill, and it touches the ring. The ring is the outer 3px, painted as a 5px spread behind the gap. It touches the shell canvas, the shell surface, the raised card, the stage surface, the readings surface, and the summary surface. For each of those surfaces the band that touches it clears 3:1. The other band can miss. That miss is why there are two bands.

| Theme | Band | Hex | Role |
| --- | --- | --- | --- |
| dark | gap | `#022c22` | `green.950`, the analyze label. 9.94:1 on the analyze fill. 5.97:1 on the ring. |
| dark | ring | `#10b981` | `green.500`, the selected stage emerald. |
| light | gap | `#ffffff` | 5.48:1 on the analyze fill and on the ring. |
| light | ring | `#047857` | `green.700`. 5.48:1 on the shell surface, 5.24:1 on the canvas, 5.01:1 on the raised card, 4.84:1 on the summary. |

The dark pair stays on the slate and emerald palette. The light ring is the same green as the light button, so the white gap is what separates the ring from the button.

Paint the bands in this order.

```css
box-shadow: var(--component-focus-gapShadow), var(--component-focus-ringShadow);
outline: 3px solid var(--component-focus-ring);
outline-offset: 2px;
```

Forced colors drop `box-shadow`. The outline remains. In `@media (forced-colors: active)`, set `outline-color` to `Highlight` and drop the shadow.

`check_tokens.mjs` scores each adjacent pair at 3:1 and writes `build/focus-contrast.tsv`. A spare pair is the band that does not touch that surface. A spare miss does not fail the run. An adjacent miss does. The same run fails when the best of the two bands is under 3:1 on any listed surface.

## Forced colors and stage names

The selected stage is a green border in the stylesheet. Forced colors replace author colors, so the selection needs a cue that is not color. Use `primitive.border.accent` (4px) on the selected card and `primitive.border.field` (2px) on the resting cards. Set the selected border to `Highlight`. The weight is the cue. Add a check mark only if a later layout drops the border.

The stage icon is `🌱`, `🌿`, or `🌸` inside `.stage-icon`. Mark that element `aria-hidden="true"` so the emoji is not part of the name. The button also contains the VPD, temperature, and humidity, so hiding the icon leaves those readings in the name. Set the button's accessible name to Seedling, Vegetation, or Flowering.

## Regenerate

From the repository root.

```
python3 design/tokens/scripts/inventory_css.py --markdown
node design/tokens/scripts/define_tokens.mjs
node design/tokens/scripts/check_tokens.mjs
```

`define_tokens.mjs` writes the three JSON files. `check_tokens.mjs` reads the resolver. It loads the one foundation file and the one light file the resolver names, resolves aliases, writes `build/dark.css` and `build/light.css`, and exits 1 if a token pair misses its bar, a focus surface is under 3:1 for both bands, or the resolver lists a different number of those files. A semantic color with alpha below 1 is composited over the background named in its pair. A translucent badge surface is composited over the raised card. A translucent analyze fill is composited over the shell surface for the analyze label and the focus gap. The product action uses that same fill and is composited over the shell canvas. The backdrop is the control named in the pair, not the shared color alias. A pair that reaches a semantic color through an alias still counts as that color's declared background. A translucent shell canvas has no further background, and the check throws. A translucent semantic color that no pair names, even through an alias, also throws. The focus shadow color is an alias of the focus color, so the light override does not repeat the hex. The script rewrites the proof CSS on every run, so a stale copy is replaced rather than reported. CI does not run these scripts. That stays true while the app does not import the tokens. A typography token becomes a `font` shorthand plus a sibling custom property for letter spacing, because one custom property cannot hold both. Edit the script, not the JSON. The dark border and the dark footer share `color.ink.muted`, so a border at that step can read as strongly as the footer.
