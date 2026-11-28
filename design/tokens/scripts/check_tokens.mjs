// Resolves the token files, writes CSS custom properties, and checks contrast.
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const buildDir = join(root, "build");

const SA98G = {
  mainTRC: 2.4,
  sRco: 0.2126729,
  sGco: 0.7151522,
  sBco: 0.072175,
  normBG: 0.56,
  normTXT: 0.57,
  revTXT: 0.62,
  revBG: 0.65,
  blkThrs: 0.022,
  blkClmp: 1.414,
  scaleBoW: 1.14,
  scaleWoB: 1.14,
  loBoWoffset: 0.027,
  loWoBoffset: 0.027,
  deltaYmin: 0.0005,
  loClip: 0.1,
};

function srgbToY(rgb) {
  const exp = (channel) => (channel / 255) ** SA98G.mainTRC;
  return SA98G.sRco * exp(rgb[0]) + SA98G.sGco * exp(rgb[1]) + SA98G.sBco * exp(rgb[2]);
}

function apca(textRgb, bgRgb) {
  let txtY = srgbToY(textRgb);
  let bgY = srgbToY(bgRgb);
  if (txtY <= SA98G.blkThrs) txtY += (SA98G.blkThrs - txtY) ** SA98G.blkClmp;
  if (bgY <= SA98G.blkThrs) bgY += (SA98G.blkThrs - bgY) ** SA98G.blkClmp;
  if (Math.abs(bgY - txtY) < SA98G.deltaYmin) return 0;
  if (bgY > txtY) {
    const sapc = (bgY ** SA98G.normBG - txtY ** SA98G.normTXT) * SA98G.scaleBoW;
    return (sapc < SA98G.loClip ? 0 : sapc - SA98G.loBoWoffset) * 100;
  }
  const sapc = (bgY ** SA98G.revBG - txtY ** SA98G.revTXT) * SA98G.scaleWoB;
  return (sapc > -SA98G.loClip ? 0 : sapc + SA98G.loWoBoffset) * 100;
}

function lin(channel) {
  const s = channel / 255;
  return s <= 0.04045 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
}

function luminance(rgb) {
  return 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2]);
}

function wcag(textRgb, bgRgb) {
  const a = luminance(textRgb);
  const b = luminance(bgRgb);
  const [hi, lo] = a > b ? [a, b] : [b, a];
  return (hi + 0.05) / (lo + 0.05);
}

function selfCheck() {
  const black = apca([0, 0, 0], [255, 255, 255]);
  const white = wcag([0, 0, 0], [255, 255, 255]);
  if (Math.abs(black - 106.04067321268862) > 0.001) {
    throw new Error(`APCA self-check failed: ${black}`);
  }
  if (Math.abs(white - 21) > 0.01) throw new Error(`WCAG self-check failed: ${white}`);
}

function readJson(name) {
  return JSON.parse(readFileSync(join(root, name), "utf8"));
}

function isToken(node) {
  return node && typeof node === "object" && Object.hasOwn(node, "$value");
}

function lookup(tree, path) {
  return path.split(".").reduce((node, key) => (node == null ? null : node[key]), tree);
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function merge(base, over) {
  if (over == null) return base;
  if (isToken(over) || isToken(base)) return clone(over);
  const out = { ...(base ?? {}) };
  for (const [key, value] of Object.entries(over)) {
    if (key.startsWith("$")) {
      out[key] = value;
      continue;
    }
    out[key] = base && typeof base[key] === "object" ? merge(base[key], value) : clone(value);
  }
  return out;
}

const aliasRe = /^\{([A-Za-z0-9.]+)\}$/;

function tokenType(token, tree, stack) {
  if (!token) throw new Error(`missing token at ${stack.join(">")}`);
  if (token.$type) return token.$type;
  const match = typeof token.$value === "string" ? token.$value.match(aliasRe) : null;
  if (!match) throw new Error(`no type for ${stack.join(".")}`);
  if (stack.includes(match[1])) throw new Error(`cycle ${match[1]}`);
  return tokenType(lookup(tree, match[1]), tree, stack.concat(match[1]));
}

function resolveValue(value, tree, stack) {
  if (typeof value === "string") {
    const match = value.match(aliasRe);
    if (!match) return value;
    if (stack.includes(match[1])) throw new Error(`cycle ${match[1]}`);
    const target = lookup(tree, match[1]);
    if (!isToken(target)) throw new Error(`alias ${match[1]} is not a token`);
    return resolveValue(target.$value, tree, stack.concat(match[1]));
  }
  if (Array.isArray(value)) return value.map((item) => resolveValue(item, tree, stack));
  if (value && typeof value === "object") {
    const out = {};
    for (const [key, item] of Object.entries(value)) out[key] = resolveValue(item, tree, stack);
    return out;
  }
  return value;
}

function walk(node, path, visit) {
  if (isToken(node)) {
    visit(path, node);
    return;
  }
  for (const [key, child] of Object.entries(node)) {
    if (key.startsWith("$")) continue;
    if (key.includes(".") || key.includes("{") || key.includes("}") || key.includes("$")) {
      throw new Error(`illegal token name ${key}`);
    }
    walk(child, path.concat(key), visit);
  }
}

function cssColor(value) {
  const [r, g, b] = value.components.map((channel) => Math.round(channel * 255));
  if (value.alpha !== undefined && value.alpha < 1) return `rgba(${r}, ${g}, ${b}, ${value.alpha})`;
  return value.hex;
}

function cssValue(type, value) {
  if (type === "color") return cssColor(value);
  if (type === "dimension" || type === "duration") return `${value.value}${value.unit}`;
  if (type === "number" || type === "fontWeight") return String(value);
  if (type === "fontFamily") {
    return value.map((name) => (name.includes(" ") ? `"${name}"` : name)).join(", ");
  }
  if (type === "cubicBezier") return `cubic-bezier(${value.join(", ")})`;
  if (type === "shadow") {
    const color = cssColor(value.color.$value ?? value.color);
    const length = (part) => `${part.value}${part.unit}`;
    return `${length(value.offsetX)} ${length(value.offsetY)} ${length(value.blur)} ${length(value.spread)} ${color}`;
  }
  if (type === "typography") {
    const family = cssValue("fontFamily", value.fontFamily);
    const size = cssValue("dimension", value.fontSize);
    const leading = value.lineHeight;
    const fontWeight = value.fontWeight;
    return `${fontWeight} ${size}/${leading} ${family}`;
  }
  throw new Error(`no CSS for ${type}`);
}

function hexToRgb(hex) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function resolvedPaint(tree, path) {
  const token = lookup(tree, path);
  const type = tokenType(token, tree, [path]);
  if (type !== "color") throw new Error(`${path} is ${type}`);
  const value = resolveValue(token.$value, tree, [path]);
  if (!value.hex) throw new Error(`${path} has no hex`);
  const alpha = value.alpha === undefined ? 1 : value.alpha;
  return { rgb: hexToRgb(value.hex), alpha };
}

function paintOver(paint, bgRgb) {
  if (paint.alpha >= 1) return paint.rgb;
  return composite(paint.rgb, paint.alpha, bgRgb);
}

const shellCanvas = "semantic.color.shell.canvas";
const shellSurface = "semantic.color.shell.surface";
const raisedCard = "semantic.color.shell.raised";
const underlay = {
  "semantic.color.priority.high.badgeSurface": raisedCard,
  "semantic.color.priority.medium.badgeSurface": raisedCard,
  "semantic.color.priority.low.badgeSurface": raisedCard,
  "component.priority.high.badgeSurface": raisedCard,
  "component.priority.medium.badgeSurface": raisedCard,
  "component.priority.low.badgeSurface": raisedCard,
  "semantic.color.analyze.fill": shellSurface,
};

function aliasTargets(tree, path) {
  const found = [];
  const seen = new Set();
  let current = path;
  while (current && !seen.has(current)) {
    seen.add(current);
    found.push(current);
    const token = lookup(tree, current);
    if (!token || typeof token.$value !== "string") break;
    const match = token.$value.match(aliasRe);
    if (!match) break;
    current = match[1];
  }
  return found;
}

function underPath(_tree, path) {
  return underlay[path] ?? shellCanvas;
}

function backdrop(tree, path, paint) {
  if (paint.alpha >= 1) return paint.rgb;
  const behind = underPath(tree, path);
  if (behind === path) throw new Error(`${path} alpha ${paint.alpha} has no declared background`);
  const base = resolvedPaint(tree, behind);
  if (base.alpha < 1) throw new Error(`${behind} alpha has no declared background`);
  return composite(paint.rgb, paint.alpha, base.rgb);
}

const pairs = [
  ["shell text on canvas", "semantic.color.shell.text", "semantic.color.shell.canvas", 4.5, "text"],
  ["shell text on surface", "semantic.color.shell.text", "semantic.color.shell.surface", 4.5, "text"],
  ["shell text on raised", "semantic.color.shell.text", "semantic.color.shell.raised", 4.5, "text"],
  ["secondary on canvas", "semantic.color.shell.textSecondary", "semantic.color.shell.canvas", 4.5, "text"],
  ["secondary on surface", "semantic.color.shell.textSecondary", "semantic.color.shell.surface", 4.5, "text"],
  ["secondary on raised", "semantic.color.shell.textSecondary", "semantic.color.shell.raised", 4.5, "text"],
  ["muted on canvas", "semantic.color.shell.muted", "semantic.color.shell.canvas", 4.5, "text"],
  ["muted on surface", "semantic.color.shell.muted", "semantic.color.shell.surface", 4.5, "text"],
  ["muted on raised", "semantic.color.shell.muted", "semantic.color.shell.raised", 4.5, "text"],
  ["waiting on canvas", "semantic.color.status.waiting", "semantic.color.shell.canvas", 4.5, "text"],
  ["loading on canvas", "semantic.color.status.loading", "semantic.color.shell.canvas", 4.5, "text"],
  ["problem on canvas", "semantic.color.status.problem", "semantic.color.shell.canvas", 4.5, "text"],
  ["VPD on stage surface", "semantic.color.stage.vpd", "component.stage.surface", 4.5, "text"],
  ["summary heading on summary", "semantic.color.summary.heading", "semantic.color.summary.surface", 4.5, "text"],
  ["summary text on summary", "semantic.color.shell.text", "semantic.color.summary.surface", 4.5, "text"],
  ["price on product surface", "semantic.color.productLink.price", "component.productLink.surface", 4.5, "text"],
  ["analyze label on fill", "semantic.color.analyze.text", "semantic.color.analyze.fill", 4.5, "text"],
  ["product action label on fill", "component.productLink.actionText", "component.productLink.action", 4.5, "text"],
  ["high badge", "semantic.color.priority.high.badgeText", "semantic.color.priority.high.badgeSurface", 4.5, "text"],
  ["medium badge", "semantic.color.priority.medium.badgeText", "semantic.color.priority.medium.badgeSurface", 4.5, "text"],
  ["low badge", "semantic.color.priority.low.badgeText", "semantic.color.priority.low.badgeSurface", 4.5, "text"],
  ["stage detail on stage", "component.stage.detail", "component.stage.surface", 4.5, "text"],
  ["recommendation title", "component.recommendation.title", "component.recommendation.surface", 4.5, "text"],
  ["recommendation description", "component.recommendation.description", "component.recommendation.surface", 4.5, "text"],
  ["readings text", "component.readings.text", "component.readings.surface", 4.5, "text"],
  ["readings placeholder", "component.readings.placeholder", "component.readings.surface", 4.5, "text"],
  ["api key hint on surface", "component.apiKey.hint", "semantic.color.shell.surface", 4.5, "text"],
  ["footer on canvas", "component.shell.footer", "semantic.color.shell.canvas", 4.5, "text"],
  ["tagline on canvas", "component.shell.headerTagline", "semantic.color.shell.canvas", 4.5, "text"],
  ["border on canvas", "semantic.color.shell.border", "semantic.color.shell.canvas", 3, "ui"],
  ["border on surface", "semantic.color.shell.border", "semantic.color.shell.surface", 3, "ui"],
  ["border on raised", "semantic.color.shell.border", "semantic.color.shell.raised", 3, "ui"],
  ["focus ring on shell canvas", "semantic.color.focus.ring", "semantic.color.shell.canvas", 3, "ui"],
  ["focus ring on shell surface", "semantic.color.focus.ring", "semantic.color.shell.surface", 3, "ui"],
  ["focus ring on shell raised", "semantic.color.focus.ring", "semantic.color.shell.raised", 3, "ui"],
  ["focus ring on stage surface", "semantic.color.focus.ring", "component.stage.surface", 3, "ui"],
  ["focus ring on readings surface", "semantic.color.focus.ring", "component.readings.surface", 3, "ui"],
  ["focus ring on summary surface", "semantic.color.focus.ring", "semantic.color.summary.surface", 3, "ui"],
  ["focus gap on analyze fill", "semantic.color.focus.gap", "semantic.color.analyze.fill", 3, "ui"],
  ["focus gap on focus ring", "semantic.color.focus.gap", "semantic.color.focus.ring", 3, "ui"],
  ["selected stage on canvas", "semantic.color.stage.selected", "semantic.color.shell.canvas", 3, "ui"],
  ["high accent on raised", "semantic.color.priority.high.accent", "semantic.color.shell.raised", 3, "ui"],
  ["medium accent on raised", "semantic.color.priority.medium.accent", "semantic.color.shell.raised", 3, "ui"],
  ["low accent on raised", "semantic.color.priority.low.accent", "semantic.color.shell.raised", 3, "ui"],
  ["product border on canvas", "semantic.color.productLink.accent", "semantic.color.shell.canvas", 3, "ui"],
  ["analyze fill on surface", "semantic.color.analyze.fill", "semantic.color.shell.surface", 3, "ui"],
];

function themeCss(tree) {
  const lines = [];
  walk(tree, [], (path, token) => {
    const type = tokenType(token, tree, path);
    const value = resolveValue(token.$value, tree, path);
    const name = "--" + path.join("-");
    lines.push(`  ${name}: ${cssValue(type, value)};`);
    if (type === "typography") {
      lines.push(`  ${name}-letter-spacing: ${cssValue("dimension", value.letterSpacing)};`);
    }
  });
  return `:root {\n${lines.join("\n")}\n}\n`;
}

function score(tree, name, textPath, bgPath, bar, kind) {
  const text = resolvedPaint(tree, textPath);
  const bg = resolvedPaint(tree, bgPath);
  const bgRgb = backdrop(tree, bgPath, bg);
  const textRgb = paintOver(text, bgRgb);
  const ratio = wcag(textRgb, bgRgb);
  const lc = apca(textRgb, bgRgb);
  const pass = ratio + 1e-9 >= bar;
  return { name, kind, bar, ratio: Number(ratio.toFixed(2)), lc: Number(lc.toFixed(1)), pass };
}

function contrastReport(theme, tree) {
  const rows = [];
  let failed = 0;
  for (const [name, textPath, bgPath, bar, kind] of pairs) {
    const row = { theme, ...score(tree, name, textPath, bgPath, bar, kind) };
    if (!row.pass) failed += 1;
    rows.push(row);
  }
  return { rows, failed };
}

const focusBands = ["semantic.color.focus.gap", "semantic.color.focus.ring"];
const focusSurfaces = [
  ["shell canvas", "semantic.color.shell.canvas"],
  ["shell surface", "semantic.color.shell.surface"],
  ["shell raised", "semantic.color.shell.raised"],
  ["stage surface", "component.stage.surface"],
  ["readings surface", "component.readings.surface"],
  ["summary surface", "semantic.color.summary.surface"],
  ["analyze fill", "semantic.color.analyze.fill"],
];

function focusMatrix(theme, tree) {
  const rows = [];
  let failed = 0;
  for (const [surfaceName, surfacePath] of focusSurfaces) {
    const scored = focusBands.map((band) => {
      const bandName = band.endsWith(".gap") ? "gap" : "ring";
      const row = score(tree, `${bandName} on ${surfaceName}`, band, surfacePath, 3, "ui");
      const adjacent = pairs.some((pair) => pair[1] === band && pair[2] === surfacePath);
      return { ...row, theme, band: bandName, surface: surfaceName, adjacent };
    });
    const best = Math.max(...scored.map((row) => row.ratio));
    if (best + 1e-9 < 3) failed += 1;
    rows.push(...scored);
  }
  const between = score(tree, "gap on ring", focusBands[0], focusBands[1], 3, "ui");
  if (!between.pass) failed += 1;
  rows.push({ ...between, theme, band: "gap", surface: "focus ring", adjacent: true });
  return { rows, failed };
}

function proveAlphaComposite(tree) {
  const copy = clone(tree);
  const ink = lookup(copy, "primitive.color.slate.100");
  ink.$value = { ...ink.$value, alpha: 0 };
  const row = score(copy, "probe", "semantic.color.shell.text", "semantic.color.shell.canvas", 4.5, "text");
  if (row.pass || row.ratio > 1.01) {
    throw new Error(`alpha 0 shell text on canvas scored ${row.ratio} pass ${row.pass}`);
  }
}

function translucent(hex, rgb, alpha) {
  return { colorSpace: "srgb", components: rgb, hex, alpha };
}

function proveAliasCoverage(tree) {
  const copy = clone(tree);
  const fill = lookup(copy, "semantic.color.analyze.fill");
  fill.$type = "color";
  fill.$value = translucent("#000000", [0, 0, 0], 0.5);
  requireDeclaredBackground(copy);
  const orphan = clone(tree);
  orphan.semantic.color.orphan = { $type: "color", $value: translucent("#ff0000", [1, 0, 0], 0.4) };
  let threw = false;
  try {
    requireDeclaredBackground(orphan);
  } catch (error) {
    threw = String(error.message).includes("semantic.color.orphan");
  }
  if (!threw) throw new Error("uncovered translucent semantic color did not throw");
}

function proveBadgeUnderlay(tree) {
  const copy = clone(tree);
  const surface = lookup(copy, "semantic.color.priority.high.badgeSurface");
  surface.$type = "color";
  surface.$value = translucent("#ef4444", [239 / 255, 68 / 255, 68 / 255], 0.54);
  const row = score(
    copy,
    "probe",
    "semantic.color.priority.high.badgeText",
    "semantic.color.priority.high.badgeSurface",
    4.5,
    "text",
  );
  const text = resolvedPaint(copy, "semantic.color.priority.high.badgeText").rgb;
  const raised = resolvedPaint(copy, "semantic.color.shell.raised").rgb;
  const canvas = resolvedPaint(copy, "semantic.color.shell.canvas").rgb;
  const want = Number(wcag(text, composite([239, 68, 68], 0.54, raised)).toFixed(2));
  const onCanvas = Number(wcag(text, composite([239, 68, 68], 0.54, canvas)).toFixed(2));
  if (row.ratio !== want) throw new Error(`badge underlay ${row.ratio} expected ${want}`);
  if (row.ratio === onCanvas) throw new Error("badge underlay used the canvas");
}

function withAnalyzeFill(tree, alpha) {
  const copy = clone(tree);
  const fill = lookup(copy, "semantic.color.analyze.fill");
  fill.$type = "color";
  fill.$value = translucent("#6ee7b7", [110 / 255, 231 / 255, 183 / 255], alpha);
  return copy;
}

function pointProductActionAtFill(tree) {
  const action = lookup(tree, "component.productLink.action");
  action.$value = "{semantic.color.analyze.fill}";
}

function proveAnalyzeBackdrop(tree) {
  const at06 = withAnalyzeFill(tree, 0.6);
  pointProductActionAtFill(at06);
  const ink = [2 / 255, 44 / 255, 34 / 255];
  paintOpaque(lookup(at06, "semantic.color.analyze.text"), "#022c22", ink);
  paintOpaque(lookup(at06, "component.productLink.actionText"), "#022c22", ink);
  const label = score(at06, "label", "semantic.color.analyze.text", "semantic.color.analyze.fill", 4.5, "text");
  const action = score(at06, "action", "component.productLink.actionText", "component.productLink.action", 4.5, "text");
  if (label.ratio !== 4.58 || !label.pass) throw new Error(`analyze label ${label.ratio} pass ${label.pass}`);
  if (action.ratio !== 4.2 || action.pass) throw new Error(`product action ${action.ratio} pass ${action.pass}`);
  const gap = score(withAnalyzeFill(tree, 0.42), "gap", "semantic.color.focus.gap", "semantic.color.analyze.fill", 3, "ui");
  if (gap.ratio !== 3.02 || !gap.pass) throw new Error(`focus gap ${gap.ratio} pass ${gap.pass}`);
}

function paintOpaque(token, hex, rgb) {
  token.$type = "color";
  token.$value = translucent(hex, rgb, 1);
}

function proveOwnProductAction(dark, light) {
  const darkCopy = clone(dark);
  const lightCopy = clone(light);
  paintOpaque(lookup(darkCopy, "semantic.color.productLink.action"), "#6ee7b7", [110 / 255, 231 / 255, 183 / 255]);
  paintOpaque(lookup(darkCopy, "component.productLink.actionText"), "#022c22", [2 / 255, 44 / 255, 34 / 255]);
  paintOpaque(lookup(lightCopy, "semantic.color.productLink.action"), "#047857", [4 / 255, 120 / 255, 87 / 255]);
  paintOpaque(lookup(lightCopy, "component.productLink.actionText"), "#ffffff", [1, 1, 1]);
  proveAnalyzeBackdrop(darkCopy);
  const darkRow = score(darkCopy, "action", "component.productLink.actionText", "component.productLink.action", 4.5, "text");
  const lightRow = score(lightCopy, "action", "component.productLink.actionText", "component.productLink.action", 4.5, "text");
  if (!darkRow.pass || darkRow.ratio !== 9.94) throw new Error(`own dark product action ${darkRow.ratio} pass ${darkRow.pass}`);
  if (!lightRow.pass || lightRow.ratio !== 5.48) throw new Error(`own light product action ${lightRow.ratio} pass ${lightRow.pass}`);
  const named = clone(light);
  paintOpaque(lookup(named, "semantic.color.productLink.action"), "#ffffff", [1, 1, 1]);
  paintOpaque(lookup(named, "component.productLink.actionText"), "#022c22", [2 / 255, 44 / 255, 34 / 255]);
  const report = contrastReport("light", named);
  const row = report.rows.find((item) => item.name === "product action label on fill");
  if (!row || row.ratio !== 15.15 || !row.pass) throw new Error(`named product action ${row?.ratio}`);
  const darkNamed = clone(dark);
  paintOpaque(lookup(darkNamed, "semantic.color.productLink.action"), "#022c22", [2 / 255, 44 / 255, 34 / 255]);
  paintOpaque(lookup(darkNamed, "component.productLink.actionText"), "#ffffff", [1, 1, 1]);
  const darkNamedRow = contrastReport("dark", darkNamed).rows.find((item) => item.name === "product action label on fill");
  if (!darkNamedRow?.pass) throw new Error(`dark own label ${darkNamedRow?.ratio} pass ${darkNamedRow?.pass}`);
}

function requireDeclaredBackground(tree) {
  const used = new Set();
  for (const row of pairs) {
    for (const path of [row[1], row[2]]) {
      for (const target of aliasTargets(tree, path)) used.add(target);
    }
  }
  const missing = [];
  walk(lookup(tree, "semantic.color"), ["semantic", "color"], (path, token) => {
    if (tokenType(token, tree, path) !== "color") return;
    const value = resolveValue(token.$value, tree, path);
    if (!value || value.alpha === undefined || value.alpha >= 1) return;
    const id = path.join(".");
    if (!used.has(id)) missing.push(id);
  });
  if (missing.length) {
    throw new Error(`translucent semantic color has no declared background: ${missing.join(", ")}`);
  }
}

const stylesheetPairs = [
  ["white on primary", "#ffffff", "#10b981", 4.5, "text"],
  ["white on primary hover", "#ffffff", "#059669", 4.5, "text"],
  ["muted on raised", "#94a3b8", "#334155", 4.5, "text"],
  ["muted on canvas", "#94a3b8", "#0f172a", 4.5, "text"],
  ["secondary text on canvas", "#cbd5e1", "#0f172a", 4.5, "text"],
  ["primary text on canvas", "#f1f5f9", "#0f172a", 4.5, "text"],
  ["violet on canvas, large title", "#8b5cf6", "#0f172a", 3, "large"],
  ["violet on canvas, normal", "#8b5cf6", "#0f172a", 4.5, "text"],
  ["green text on canvas", "#10b981", "#0f172a", 4.5, "text"],
  ["error on canvas", "#fca5a5", "#0f172a", 4.5, "text"],
  ["border on canvas", "#334155", "#0f172a", 3, "ui"],
  ["border on surface", "#334155", "#1e293b", 3, "ui"],
  ["high edge on raised", "#ef4444", "#334155", 3, "ui"],
  ["medium edge on raised", "#f59e0b", "#334155", 3, "ui"],
  ["low edge on raised", "#3b82f6", "#334155", 3, "ui"],
];

function composite(fg, alpha, bg) {
  return fg.map((channel, index) => Math.round(channel * alpha + bg[index] * (1 - alpha)));
}

function measure(name, text, bg, bar, kind) {
  const ratio = wcag(text, bg);
  const lc = apca(text, bg);
  const toHex = (rgb) => "#" + rgb.map((channel) => channel.toString(16).padStart(2, "0")).join("");
  return {
    name,
    kind,
    bar,
    ratio: Number(ratio.toFixed(2)),
    lc: Number(lc.toFixed(1)),
    pass: ratio + 1e-9 >= bar,
    text: toHex(text),
    bg: toHex(bg),
  };
}

function stylesheetReport() {
  const rows = stylesheetPairs.map(([name, text, bg, bar, kind]) => measure(name, hexToRgb(text), hexToRgb(bg), bar, kind));
  const ring = composite(hexToRgb("#10b981"), 0.1, hexToRgb("#1e293b"));
  rows.push(measure("focus ring 10 percent over surface", ring, hexToRgb("#1e293b"), 3, "ui"));
  return rows;
}

function loadResolver() {
  const resolver = readJson("grow_assist.resolver.json");
  if (resolver.version !== "2025.10") throw new Error(`resolver version ${resolver.version}`);
  const sources = resolver.sets.foundation.sources;
  if (!Array.isArray(sources) || sources.length !== 1) {
    throw new Error(`foundation sources ${sources?.length ?? 0}, expected 1`);
  }
  const foundation = readJson(sources[0].$ref);
  const scheme = resolver.modifiers.colorScheme;
  if (scheme.default !== "dark") throw new Error(`colorScheme default ${scheme.default}`);
  if (scheme.contexts.dark.length !== 0) throw new Error("dark context should be empty");
  const lightSources = scheme.contexts.light;
  if (!Array.isArray(lightSources) || lightSources.length !== 1) {
    throw new Error(`light context ${lightSources?.length ?? 0}, expected 1`);
  }
  const lightRef = lightSources[0].$ref;
  return { dark: foundation, light: merge(foundation, readJson(lightRef)) };
}

function main() {
  selfCheck();
  const { dark: darkTree, light: lightTree } = loadResolver();
  proveAlphaComposite(darkTree);
  proveAliasCoverage(darkTree);
  proveAliasCoverage(lightTree);
  proveBadgeUnderlay(darkTree);
  proveBadgeUnderlay(lightTree);
  proveOwnProductAction(darkTree, lightTree);
  requireDeclaredBackground(darkTree);
  requireDeclaredBackground(lightTree);
  mkdirSync(buildDir, { recursive: true });
  writeFileSync(join(buildDir, "dark.css"), themeCss(darkTree));
  writeFileSync(join(buildDir, "light.css"), themeCss(lightTree));
  const dark = contrastReport("dark", darkTree);
  const lightReport = contrastReport("light", lightTree);
  const rows = [...dark.rows, ...lightReport.rows];
  writeFileSync(join(buildDir, "contrast.json"), JSON.stringify(rows, null, 2) + "\n");
  const header = "theme\tpair\tkind\tbar\tratio\tLc\tresult";
  const body = rows
    .map((row) => [row.theme, row.name, row.kind, row.bar, row.ratio.toFixed(2), row.lc.toFixed(1), row.pass ? "pass" : "fail"].join("\t"))
    .join("\n");
  writeFileSync(join(buildDir, "contrast.tsv"), header + "\n" + body + "\n");
  const current = stylesheetReport();
  writeFileSync(join(buildDir, "stylesheet-contrast.json"), JSON.stringify(current, null, 2) + "\n");
  const currentBody = current
    .map((row) => [row.name, row.kind, row.bar, row.ratio.toFixed(2), row.lc.toFixed(1), row.pass ? "pass" : "fail", row.text, row.bg].join("\t"))
    .join("\n");
  writeFileSync(
    join(buildDir, "stylesheet-contrast.tsv"),
    "pair\tkind\tbar\tratio\tLc\tresult\ttext\tbackground\n" + currentBody + "\n",
  );
  console.log("stylesheet fails", current.filter((row) => !row.pass).length);
  const darkFocus = focusMatrix("dark", darkTree);
  const lightFocus = focusMatrix("light", lightTree);
  const focusRows = [...darkFocus.rows, ...lightFocus.rows];
  writeFileSync(join(buildDir, "focus-contrast.json"), JSON.stringify(focusRows, null, 2) + "\n");
  const focusBody = focusRows
    .map((row) =>
      [row.theme, row.band, row.surface, row.ratio.toFixed(2), row.lc.toFixed(1), row.pass ? "pass" : "fail", row.adjacent ? "adjacent" : "spare"].join(
        "\t",
      ),
    )
    .join("\n");
  writeFileSync(
    join(buildDir, "focus-contrast.tsv"),
    "theme\tband\tsurface\tratio\tLc\tresult\trole\n" + focusBody + "\n",
  );
  const focusFailed = darkFocus.failed + lightFocus.failed;
  console.log(`focus surfaces failed ${focusFailed}`);
  const failed = dark.failed + lightReport.failed + focusFailed;
  console.log(`pairs ${rows.length}, failed ${failed}`);
  for (const row of rows.filter((row) => !row.pass)) {
    console.log(`FAIL ${row.theme} ${row.name} ${row.ratio} Lc ${row.lc} bar ${row.bar}`);
  }
  if (failed) process.exit(1);
}

main();
