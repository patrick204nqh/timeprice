# timeprice Design System - Full Content

```yaml
version: alpha
name: timeprice
description: |
  timeprice is a single-page historical money calculator that runs an entire
  Ruby VM in the browser via ruby.wasm. The UI is built on Tailwind's warm
  "stone" neutral ramp with a single emerald accent reserved for the
  converted-amount in the hero sentence, plus one amber state for the Ruby
  VM warm-up pill. The whole system is flat — no drop shadows, no gradients,
  no web fonts. Surfaces lift via 1px hairline borders and rounded corners,
  never elevation. Monospace (ui-monospace) with `tabular-nums` is used
  everywhere numbers, currency codes, dates, or code appear; the system sans
  stack carries everything else. Dark mode is first-class and applied before
  paint to avoid flash.

colors:
  ink: "#1c1917"
  ink-on-dark: "#f5f5f4"
  body: "#57534e"
  body-on-dark: "#a8a29e"
  mute: "#78716c"
  label: "#44403c"
  label-on-dark: "#d6d3d1"
  canvas: "#fafaf9"
  canvas-on-dark: "#0c0a09"
  surface-card: "#ffffff"
  surface-card-on-dark: "#1c1917"
  surface-inset: "#f5f5f4"
  surface-inset-on-dark: "rgba(41,37,36,0.5)"
  surface-code: "#1c1917"
  hairline: "#e7e5e4"
  hairline-on-dark: "#292524"
  hairline-input: "#d6d3d1"
  hairline-input-on-dark: "#44403c"
  accent: "#047857"
  accent-on-dark: "#34d399"
  warming: "#fbbf24"
  link: "currentColor"

typography:
  hero:
    fontFamily: ui-sans-serif (system)
    fontSize: 48px
    fontSizeMobile: 30px
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: -0.025em
  section-title:
    fontFamily: ui-sans-serif (system)
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.4
  result-value:
    fontFamily: ui-monospace
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.25
    fontFeature: "tnum"
  body-md:
    fontFamily: ui-sans-serif (system)
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
  body-sm:
    fontFamily: ui-sans-serif (system)
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.43
  label:
    fontFamily: ui-sans-serif (system)
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.4
  caption:
    fontFamily: ui-sans-serif (system)
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
  mono-input:
    fontFamily: ui-monospace
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.43
  mono-meta:
    fontFamily: ui-monospace
    fontSize: 12px
    fontWeight: 400
    lineHeight: 1.4
    fontFeature: "tnum"
  code:
    fontFamily: ui-monospace
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.6
  wordmark:
    fontFamily: ui-monospace
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.4

rounded:
  none: 0px
  sm: 4px
  md: 6px
  lg: 12px
  full: 9999px

spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
  xxl: 32px
  section: 64px

components:
  header-bar:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.none}"
    padding: 16px
    height: 64px
  wordmark:
    typography: "{typography.wordmark}"
    textColor: "{colors.ink}"
  theme-toggle:
    backgroundColor: "transparent"
    textColor: "{colors.body}"
    rounded: "{rounded.md}"
    size: 32px
  hero-sentence:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.hero}"
    rounded: "{rounded.none}"
  hero-accent-span:
    textColor: "{colors.accent}"
    typography: "{typography.hero}"
    fontFeature: "tnum"
  calc-card:
    backgroundColor: "{colors.surface-card}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    border: "1px {colors.hairline}"
    padding: 24px
  card-header-strip:
    backgroundColor: "{colors.surface-card}"
    textColor: "{colors.label}"
    typography: "{typography.label}"
    borderBottom: "1px {colors.hairline}"
    padding: 10px 16px
    height: 40px
  status-pill:
    backgroundColor: "transparent"
    textColor: "{colors.mute}"
    typography: "{typography.label}"
    gap: 6px
  status-dot-warming:
    backgroundColor: "{colors.warming}"
    rounded: "{rounded.full}"
    size: 8px
    animation: "pulse"
  status-dot-ready:
    backgroundColor: "{colors.accent}"
    rounded: "{rounded.full}"
    size: 8px
  text-input:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.mono-input}"
    rounded: "{rounded.md}"
    border: "1px {colors.hairline-input}"
    padding: 8px 12px
  select-input:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.mono-input}"
    rounded: "{rounded.md}"
    border: "1px {colors.hairline-input}"
    padding: 8px 12px
  form-label:
    typography: "{typography.label}"
    textColor: "{colors.body}"
  disclosure-toggle:
    backgroundColor: "transparent"
    textColor: "{colors.body}"
    typography: "{typography.label}"
    textDecoration: "underline dotted"
    textUnderlineOffset: 4px
  result-block:
    backgroundColor: "{colors.surface-inset}"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 16px
  result-value:
    typography: "{typography.result-value}"
    textColor: "{colors.ink}"
  result-mode:
    typography: "{typography.label}"
    textColor: "{colors.mute}"
  result-meta:
    typography: "{typography.mono-meta}"
    textColor: "{colors.mute}"
  example-chip:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.full}"
    border: "1px {colors.hairline-input}"
    padding: 6px 10px
    hoverBackground: "{colors.surface-inset}"
  code-block:
    backgroundColor: "{colors.surface-code}"
    textColor: "{colors.ink-on-dark}"
    typography: "{typography.code}"
    rounded: "{rounded.md}"
    padding: 16px
  copy-button-on-code:
    backgroundColor: "#44403c"
    textColor: "{colors.ink-on-dark}"
    typography: "{typography.label}"
    rounded: "{rounded.sm}"
    padding: 4px 8px
    position: "absolute top:8px right:8px"
  copy-button:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    border: "1px {colors.hairline-input}"
    padding: 8px 12px
    hoverBackground: "{colors.surface-inset}"
  install-card:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.lg}"
    border: "1px {colors.hairline}"
    padding: 20px
  meta-line:
    typography: "{typography.caption}"
    textColor: "{colors.mute}"
    separator: " · "
  footer:
    backgroundColor: "{colors.canvas}"
    textColor: "{colors.mute}"
    typography: "{typography.body-sm}"
    borderTop: "1px {colors.hairline}"
    padding: 24px 16px
```

## Overview

timeprice looks like a CLI tool that learned just enough manners to live on the open web. Every page opens on `{colors.canvas}` (`#fafaf9` in light, `#0c0a09` in dark), and the loudest element on the canvas is not a button — it's an English sentence headline that *contains the calculation* ("**$100 in 1990** is worth **$242.09 in 2024**"). The converted amount, set in monospace with `tabular-nums` and tinted `{colors.accent}` emerald, is the single visual anchor of the page.

Below the hero, a single `{component.calc-card}` carries the entire product. The card uses a 1px hairline border, `{rounded.lg}` (12px) corners, and a small "card header strip" that names the surface and parks a live status pill on the right. Inside, the form is unornamented — monospace inputs and selects with the same hairline border, labels at 12px, and a result block that re-uses the warmer `{colors.surface-inset}` background to register as inset rather than elevated. Beneath the result, a row of `{component.example-chip}` pills offers one-tap demos, and two dotted-underline disclosures expand into a date-picker row and a code block showing the equivalent Ruby.

The brand never warms to drop shadows, gradients, or web fonts. Depth is built from three signals only: hairline borders, rounded corners, and a one-step background shift between card and inset. Dark mode is not a skin — every token has a `dark:` pair, applied via a tiny inline script *before* Tailwind paints, so there is no theme flash on load.

**Key Characteristics:**
- Warm "stone" neutral ramp (`{colors.canvas}` → `{colors.surface-card}` → `{colors.surface-inset}`) replaces the conventional cool-gray developer-tool palette.
- A single emerald accent (`{colors.accent}` `#047857`, dark `#34d399`) used **only** for the converted-amount span in the hero sentence — nowhere else.
- A single amber state (`{colors.warming}` `#fbbf24`) used **only** for the pulsing dot of the Ruby-VM warm-up pill.
- Monospace + `tabular-nums` for every number, year, currency code, date, version, and code snippet; system sans for prose. The lanes are strict.
- No drop shadows, no gradients, no glassmorphism, no web fonts, no icon library. Elevation is flat.
- The hero headline *is* the result — it updates live as the user edits inputs. There is no separate "calculate" button.
- Dark mode applied pre-paint via inline script; tri-state (Light / Dark / System) toggle stored in `localStorage`.

## Colors

### Brand & Accent
- **Accent Emerald** (`{colors.accent}` — `#047857`, dark `{colors.accent-on-dark}` — `#34d399`): the brand's single accent. Reserved exclusively for the converted-amount span in `{component.hero-sentence}`. Scarcity is the point — if a second emerald pixel appears on the page, the headline loses its anchor.
- **Warming Amber** (`{colors.warming}` — `#fbbf24`): used only as the background of `{component.status-dot-warming}` while the Ruby VM is loading. Switches to `{colors.accent}` (or the dot is removed) once ready.

### Surface
- **Canvas** (`{colors.canvas}` — `#fafaf9`, dark `{colors.canvas-on-dark}` — `#0c0a09`): the default page background. Warm off-white in light mode, near-black with a warm cast in dark.
- **Surface Card** (`{colors.surface-card}` — `#ffffff`, dark `{colors.surface-card-on-dark}` — `#1c1917`): the calc card and install card. One step lighter than canvas in dark mode, pure white in light.
- **Surface Inset** (`{colors.surface-inset}` — `#f5f5f4`, dark `{colors.surface-inset-on-dark}` — `rgba(41,37,36,0.5)`): the result block inside the calc card. One step *warmer* than the card surface — inset, never elevated.
- **Surface Code** (`{colors.surface-code}` — `#1c1917`): code blocks (`gem install` snippet, equivalent-Ruby snippet) ship with the same dark background in both modes. Code is always rendered against dark.
- **Hairline** (`{colors.hairline}` — `#e7e5e4`, dark `{colors.hairline-on-dark}` — `#292524`): the 1px border that wraps cards, separates the header strip from the card body, and underlines the global header and footer.
- **Hairline Input** (`{colors.hairline-input}` — `#d6d3d1`, dark `{colors.hairline-input-on-dark}` — `#44403c`): one step stronger than the default hairline, used on inputs, selects, chips, and outline buttons so interactive surfaces register.

### Text
- **Ink** (`{colors.ink}` — `#1c1917`, dark `{colors.ink-on-dark}` — `#f5f5f4`): primary text colour. Carries the hero headline, result value, wordmark, and body prose.
- **Body** (`{colors.body}` — `#57534e`, dark `{colors.body-on-dark}` — `#a8a29e`): secondary prose (hero subtitle, helper text below labels).
- **Label** (`{colors.label}` — `#44403c`, dark `{colors.label-on-dark}` — `#d6d3d1`): label colour for the card header strip ("Money calculator") and other 12px UI labels.
- **Mute** (`{colors.mute}` — `#78716c`): captions, meta, the data-sources trust line, the connective words ("is worth", period) in the hero sentence, and footer copy. Mute reads the same in both modes.

### Semantic
- The system **does not have** red, blue, or purple semantic colours. Errors and out-of-range states reuse `{colors.mute}` for the message and `{colors.warming}` for any indicator dot. If a future error state needs more weight, prefer adding `{rounded.md}` `{colors.surface-inset}` framing around the message before adding a new colour.

## Typography

### Font Family

timeprice ships with a **zero-web-font** stack — every face is a system or generic family, so first paint is instant and the page works offline.

- **System sans** — `ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`. Used for all prose, labels, helper text, and button labels.
- **System monospace** — `ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace`. Used for the wordmark, every number/year/currency-code/date, inputs that take numeric values, the version/refresh metadata, and code blocks.
- **`.tabular` utility** — applies `font-variant-numeric: tabular-nums` and is paired with the monospace stack on any value that changes during typing so the layout doesn't jitter on each keystroke.

There is no substitute table because there are no proprietary faces.

### Hierarchy

| Token | Size | Weight | Line Height | Letter Spacing | Family | Use |
|---|---|---|---|---|---|---|
| `{typography.hero}` | 48px (mobile 30px) | 700 | 1.1 | -0.025em | sans | Hero sentence headline. One per page. |
| `{typography.section-title}` | 14px | 600 | 1.4 | 0 | sans | Card header strip ("Money calculator"), small section titles, install-card title. |
| `{typography.result-value}` | 24px | 600 | 1.25 | 0 | mono + tabular | Converted amount in `{component.result-block}`. |
| `{typography.body-md}` | 16px | 400 | 1.5 | 0 | sans | Default body prose. |
| `{typography.body-sm}` | 14px | 400 | 1.43 | 0 | sans | Subtitle under the hero, install-card copy, footer copy, nav links. |
| `{typography.label}` | 12px | 500 | 1.4 | 0 | sans | Form labels, chip text, disclosure-toggle labels. |
| `{typography.caption}` | 12px | 400 | 1.4 | 0 | sans | Helper text, meta hints, mode label inside the result block. |
| `{typography.mono-input}` | 14px | 400 | 1.43 | 0 | mono | All input/select values. |
| `{typography.mono-meta}` | 12px | 400 | 1.4 | 0 | mono + tabular | Trust-line metadata (refresh date, gem version), result meta line. |
| `{typography.code}` | 14px | 400 | 1.6 | 0 | mono | Code blocks (`gem install`, equivalent-Ruby snippet). |
| `{typography.wordmark}` | 18px | 600 | 1.4 | 0 | mono | Header wordmark ("timeprice"). |

### Principles
- **The family change carries hierarchy, not the weight bump.** Sans for prose, mono for numbers and code. Within sans, only `{typography.hero}` reaches 700 weight; `{typography.section-title}` and `{typography.result-value}` use 600; everything else is 400/500.
- **Tabular numerics everywhere a value can change.** Inputs, the hero accent span, the result value, the result detail line, the meta line — all carry `tabular-nums` so digit transitions don't shift the layout.
- **The hero is one sentence, not three lines.** Domaine-style typographic blocks are not the brand; flowing English with monospace insets is.
- **Dotted underlines for disclosure affordances.** `{component.disclosure-toggle}` uses `text-decoration: underline dotted; text-underline-offset: 4px` to signal "click to expand" without an icon library.

## Layout

### Spacing System
- **Base unit**: 4px, with the working scale on multiples of 4.
- **Tokens**: `{spacing.xs}` 4px · `{spacing.sm}` 8px · `{spacing.md}` 12px · `{spacing.lg}` 16px · `{spacing.xl}` 24px · `{spacing.xxl}` 32px · `{spacing.section}` 64px.
- **Page rhythm**: header `py-4` (16px), main `py-8` (32px), `space-y-8` (32px) between sections, footer `mt-12` (48px).
- **Card internal padding**: `p-4 sm:p-6` — 16px on mobile, 24px from `sm` up.
- **Inline gaps**: `gap-2 sm:gap-3` (8/12px) for form rows; `gap-3`/`gap-4` (12/16px) for header and footer rows.

### Grid & Container
- **Max content width**: `max-w-4xl` (896px). Everything — header, main, footer — sits inside the same `max-w-4xl mx-auto px-4` shell. Never wider.
- **Form grid**: the From/To rows use `grid-cols-1 sm:grid-cols-[max-content_1fr_max-content_1fr]` so labels, selects, the inline word "in", and year inputs align across both rows.
- **Date picker grid**: a simple `grid-cols-2 gap-3` row revealed by the "Use specific dates" disclosure.
- **Example chips**: `flex flex-wrap gap-2` row directly under the result block.
- **Install card**: `flex-col sm:flex-row` — stacks copy + CTA on mobile, splits left/right at `sm`.

### Whitespace Philosophy
- Whitespace is functional, not editorial. The card is the hero; padding inside it (16–24px) is generous enough to read at small viewports, but the surrounding canvas never opens beyond `space-y-8`.
- Hairlines (`{colors.hairline}`) carry the role drop shadows would in a brighter system. The flat canvas suppresses traditional shadow depth entirely.
- Trust signals (`{component.meta-line}`) sit *immediately* below the calc card with no extra gap — they read as part of the card, not a separate band.

## Elevation & Depth

| Level | Treatment | Use |
|---|---|---|
| 0 — flat | No border, no shadow | Default canvas, hero sentence, install-card body. |
| 1 — surface card | `{colors.surface-card}` + 1px `{colors.hairline}` + `{rounded.lg}` | `{component.calc-card}`, `{component.install-card}`. |
| 2 — inset | `{colors.surface-inset}` + `{rounded.md}` (no border) | `{component.result-block}` inside the calc card. |
| 3 — code well | `{colors.surface-code}` + `{rounded.md}` (no border) | `{component.code-block}` for install snippet and equivalent-Ruby. |

The system has **no traditional drop shadow language**. Every surface either gets a 1px hairline border *or* a one-step background shift (warmer → card → inset). Elevation 2 (inset) and elevation 3 (code well) read as *deeper* than the card, not lifted above it — depth runs downward, not upward.

### Decorative Depth
- **Status pill** — the only animated element in the system. `{component.status-dot-warming}` pulses amber during VM warm-up and either switches to `{component.status-dot-ready}` (solid emerald) or is removed once Ruby is ready. There is no spinner, no skeleton, no progress bar.
- **Disclosure triangles** — `▸` glyph that rotates to `▾` on open via `group-open:rotate-90 transition-transform`. This is the only `transition` in the system.
- **Copy button on dark code** — `{component.copy-button-on-code}` is the only component that ships with a baked-in non-stone background (`#44403c`) so it reads against the always-dark code well.

## Shapes

### Border Radius Scale

| Token | Value | Use |
|---|---|---|
| `{rounded.none}` | 0px | Header bar, footer bar, full-bleed sections. |
| `{rounded.sm}` | 4px | Copy button inside the code well. |
| `{rounded.md}` | 6px | Inputs, selects, outline buttons, theme toggle, result block, code blocks. |
| `{rounded.lg}` | 12px | `{component.calc-card}`, `{component.install-card}`. |
| `{rounded.full}` | 9999px | Example chips, status dot. |

### Photography Geometry
- The system uses **no photography**. Visual interest comes from typography, monospace numerics, and the one-emerald-pixel rule.
- No avatars, no illustrations, no diagrams. If a future doc page adds historical-CPI charts, they should render in stone strokes + a single emerald series line on a transparent background, with no grid fill.

## Components

### Buttons

**`copy-button`** — outline copy button
- Background `transparent`, label `{colors.ink}`, 1px `{colors.hairline-input}`, type `{typography.label}`, `rounded: {rounded.md}`, padding `8px 12px`.
- Hover: `{colors.surface-inset}` background. Used on the install card next to the `gem install timeprice` code block.

**`copy-button-on-code`** — overlay copy button
- Background `#44403c`, label `{colors.ink-on-dark}`, type `{typography.label}`, `rounded: {rounded.sm}`, padding `4px 8px`, absolutely positioned `top: 8px right: 8px`.
- Used inside `{component.code-block}` shells to copy the snippet contents.

**`theme-toggle`** — tri-state theme switcher
- Background `transparent`, icon `{colors.body}`, 1px `{colors.hairline-input}`, `rounded: {rounded.md}`, 32×32px square.
- Cycles Light → Dark → System. Persists choice to `localStorage["theme"]`. The icon swaps with state.

The system intentionally has **no primary CTA button**. The hero sentence is the action — editing inputs updates the result live. The closest thing to a CTA is the `gem install timeprice` code block + copy pair on the install card.

### Cards & Containers

**`calc-card`** — the product
- Background `{colors.surface-card}`, text `{colors.ink}`, 1px `{colors.hairline}`, `rounded: {rounded.lg}`, padding `16px` (mobile) / `24px` (`sm+`).
- Carries a `{component.card-header-strip}` along the top, then form, then `{component.result-block}`, then chip row, then two disclosure rows.

**`card-header-strip`** — card title bar
- Background `{colors.surface-card}` (continues the card), text `{colors.label}`, type `{typography.section-title}`, `borderBottom: 1px {colors.hairline}`, padding `10px 16px`.
- Left: surface name ("Money calculator"). Right: `{component.status-pill}`.

**`result-block`** — calculation output
- Background `{colors.surface-inset}`, text `{colors.ink}`, `rounded: {rounded.md}`, padding `16px`, no border.
- Contains four stacked lines: mode label (`{typography.label}` + `{colors.mute}`), result value (`{typography.result-value}`), detail line (`{typography.body-sm}` + `{colors.body}`, tabular), and meta line (`{typography.mono-meta}` + `{colors.mute}`).
- Uses `role="status"` + `aria-live="polite"` + `aria-atomic="true"` so screen readers announce updates.

**`code-block`** — code well
- Background `{colors.surface-code}`, text `{colors.ink-on-dark}`, type `{typography.code}`, `rounded: {rounded.md}`, padding `16px`, no border. Always rendered against the dark surface regardless of theme.
- Paired with `{component.copy-button-on-code}` absolutely positioned in the top-right.

**`install-card`** — Ruby-developer CTA card
- Background `transparent`, text `{colors.ink}`, 1px `{colors.hairline}`, `rounded: {rounded.lg}`, padding `20px`.
- Two-column at `sm+` (copy left, code-block + copy-button right), stacked on mobile. No emerald accent here — install is supporting, not headline.

### Inputs & Forms

**`text-input`** — number input
- Background `transparent`, text `{colors.ink}`, type `{typography.mono-input}`, 1px `{colors.hairline-input}`, `rounded: {rounded.md}`, padding `8px 12px`.
- Numeric variants use `inputmode="decimal"` or `inputmode="numeric"` and `type="number"` for mobile keypads. Year inputs add `min`/`max`/`step` bounds reflecting the data range.

**`select-input`** — currency select
- Same surface treatment as `{component.text-input}`. Options are formatted `"USD — US dollar"`: the three-letter code first (monospace-rendered by the value font), em-dash, full name.

**`form-label`** — small label
- Type `{typography.label}`, text `{colors.body}`, margin `mb-1` (4px) when stacked above the input, or right-aligned (`sm:justify-self-end`) for inline grid rows.

**`disclosure-toggle`** — collapsible affordance
- Background `transparent`, text `{colors.body}`, type `{typography.label}`, `text-decoration: underline dotted`, `text-underline-offset: 4px`.
- Prefixed with a `▸` glyph that rotates to `▾` on open. Used for "Use specific dates" (custom button + hidden `<div>`) and "Show equivalent Ruby" (native `<details>`).

### Navigation

**`header-bar`** — global header
- Background `{colors.canvas}`, text `{colors.ink}`, type `{typography.body-sm}`, `rounded: {rounded.none}`, `borderBottom: 1px {colors.hairline}`, height 64px, inner `max-w-4xl mx-auto px-4`.
- Left: `{component.wordmark}` + small muted tagline ("historical money calculator", `hidden sm:inline`).
- Right: GitHub link (`hover:underline`) + `{component.theme-toggle}`.

**`footer`** — global footer
- Background `{colors.canvas}`, text `{colors.mute}`, type `{typography.body-sm}`, `borderTop: 1px {colors.hairline}`, padding `24px 16px`, `mt-12` (48px) above.
- Two lines, `flex-col sm:flex-row sm:justify-between`: left is license + DATA_LICENSES.md link, right is a small monospace note about `ruby.wasm`.

### Signature Components

**`hero-sentence`** — the headline-as-result
- Text `{colors.ink}`, type `{typography.hero}` (48px desktop, 30px mobile), 700 weight, tight tracking (`-0.025em`).
- Contains **three spans**:
  1. `{component.hero-accent-span}` "from" amount/currency/year (mono + tabular, but `text-ink`).
  2. Mute connective ("is worth ").
  3. `{component.hero-accent-span}` "to" amount/currency/year (mono + tabular + `{colors.accent}` emerald).
- Closes with a muted period. Updates live on every input change.

**`status-pill`** — VM warm-up indicator
- Layout: flex row, `gap: 6px`, text `{colors.mute}`, type `{typography.label}`.
- Dot: `{component.status-dot-warming}` (8px, amber, `animate-pulse`) while loading, `{component.status-dot-ready}` (8px, emerald, no animation) once ready, or remove entirely.
- Label: "Ruby VM warming…" → "Ruby VM ready" or hidden.

**`example-chip`** — preset calculation
- Background `transparent`, text `{colors.ink}`, type `{typography.label}`, 1px `{colors.hairline-input}`, `rounded: {rounded.full}`, padding `6px 10px`.
- Hover: `{colors.surface-inset}` background.
- Carries a `data-example="FROM_CCY:FROM_YEAR|TO_CCY:TO_YEAR|AMOUNT"` payload; the chip *is* the preset URL.

**`meta-line`** — trust signal
- Centred row directly under the calc card. Type `{typography.caption}`, text `{colors.mute}`, separator ` · ` (mid-dot).
- Format: `Data: BLS · ONS · Eurostat · IMF · ECB · GSO · refreshed YYYY-MM-DD · gem vX.Y.Z`. The date and version render in `{typography.mono-meta}`. This line is non-negotiable — it doubles as the brand's trust mark.

## Do's and Don'ts

### Do
- Use `{colors.canvas}` as the default page background (warm off-white in light, warm near-black in dark). Mirror every light token with its `-on-dark` pair.
- Reserve `{colors.accent}` (emerald) **only** for the "to" span in `{component.hero-sentence}`. One emerald region per viewport.
- Reserve `{colors.warming}` (amber) **only** for the Ruby-VM warming dot. Switch to `{colors.accent}` or remove once ready.
- Apply monospace + `tabular-nums` to every number, currency code, year, date, version string, and code snippet. Keep prose in the system sans stack.
- Build elevation from 1px hairlines + rounded corners + the warmer `{colors.surface-inset}` step. Run depth *downward* (inset) not upward (shadow).
- Update `{component.hero-sentence}` live on every input change — the headline is the result.
- Apply the dark-mode class via inline `<script>` in `<head>` *before* Tailwind paints. No theme flash.
- Use `<details>` or dotted-underline disclosure toggles for any "show more" affordance — no modals.
- Anchor the `{component.meta-line}` trust signal directly under the calc card on every variant of this page.

### Don't
- Don't introduce a second accent colour. If something needs differentiation, use weight, size, monospace, or `{colors.mute}`.
- Don't apply `{colors.accent}` to buttons, borders, hover states, or chart strokes — emerald is for the headline result span only.
- Don't add drop shadows, gradients, glows, or backdrop blur. The system is flat.
- Don't introduce web fonts. The stacks are `ui-sans-serif` and `ui-monospace`, both system-resolved.
- Don't add an icon library. The system uses ▸/▾ glyphs, inline SVG for the theme icon, and the unicode mid-dot.
- Don't render code outside `{component.code-block}` — even inline code samples should use the dark-on-dark surface.
- Don't loosen the `max-w-4xl` container. The site is one column, one card, one job.
- Don't add a "calculate" button. The hero is the result.
- Don't bump body weight to 600 for emphasis. Switch to mono, or use `{typography.section-title}`.
- Don't introduce modals or multi-step forms. If something needs more space, use a `<details>` disclosure or a new page.

## Responsive Behavior

### Breakpoints

| Name | Width | Key Changes |
|---|---|---|
| Desktop | ≥ 640px (`sm` and up) | Hero at 48px; From/To rows promote to the 4-column inline grid; install-card splits row; header tagline visible; card padding 24px. |
| Mobile | < 640px | Hero clamps to 30px; From/To rows stack to single column with labels above; install-card stacks copy above CTA; header tagline hidden; card padding 16px. |

Only one breakpoint (`sm`, 640px) is used. The container caps at `max-w-4xl` (896px), so no larger breakpoint adjustments are required.

### Touch Targets
- All inputs, selects, and chips are ≥ 32px tall on mobile via padding adjustment.
- `{component.theme-toggle}` is exactly 32×32px.
- `{component.example-chip}` is ~28px tall — acceptable because it's a row of optional presets, not the primary control.

### Collapsing Strategy
- **Form grid**: `grid-cols-1` on mobile, `grid-cols-[max-content_1fr_max-content_1fr]` at `sm+`. Labels move from above the input (mobile) to inline right-aligned (`sm:justify-self-end`, desktop).
- **Install card**: `flex-col` on mobile, `flex-row` at `sm+`. The CTA (code block + copy button) moves from below the copy to its right.
- **Header tagline**: hidden below `sm` (`hidden sm:inline`).
- **Footer**: stacks below `sm`, splits left/right at `sm+`.

### Image Behavior
- There are no images, illustrations, or photographs in this system. Nothing to scale.
- Atmospheric effects (glows, gradients) do not exist. Nothing to reflow.

## Iteration Guide

1. Focus on ONE component at a time. Most surfaces share `{colors.surface-card}` with `{rounded.lg}` and `1px {colors.hairline}` — only the role-specific tokens (`{component.result-block}`, `{component.code-block}`) shift between variants.
2. Reference component names and tokens directly (`{colors.accent}`, `{component.hero-sentence}`, `{rounded.lg}`) — do not paraphrase.
3. Mirror every new colour with a `-on-dark` pair. Dark mode is not optional.
4. Add new variants as separate entries (`status-dot-warming`, `status-dot-ready`, `copy-button-on-code`) — do not bury them in prose.
5. Default body type to `{typography.body-md}`; reach for `{typography.section-title}` only on card header strips and small section titles.
6. Keep `{colors.accent}` (emerald) scarce — if more than one emerald region appears per viewport, ask whether the second one should drop to `{colors.ink}` or `{colors.mute}` instead.
7. If a future surface needs a "primary CTA button", question the premise first. The calc card has no submit button by design; new surfaces should follow the same pattern (live updates, no form submit).

## Known Gaps

- Focus rings are documented only implicitly (browser default). A focused-state token (`{colors.hairline-strong}` ring at 2px) is the natural next addition.
- Disabled state for `{component.text-input}` / `{component.select-input}` is not specified — currently relies on the native browser disabled style.
- Error state for an out-of-range year or currency is not specified — currently rendered as `{typography.caption}` + `{colors.mute}` text in `#calc-range-hint`. If a future variant needs more weight, the natural step is wrapping the message in a `{colors.surface-inset}` block (no new colour required).
- Chart styling is not specified. If a historical-CPI chart is added later, it should use `{colors.mute}` strokes + a single `{colors.accent}` series line on transparent background, with no grid fill.
- The "Ruby VM ready" steady state is named here but the live site currently removes the pill entirely when ready. Either treatment is acceptable; do not introduce a third.
- Marketing pages (blog, docs index) are out of scope. This system is tuned for the calculator surface; a future docs surface would need to extend the type scale, not the colour system.
