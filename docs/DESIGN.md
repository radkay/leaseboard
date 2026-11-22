# Design

One visual language for the board, the admin and the public listing page. The direction is
**editorial restraint**: quality through type, spacing and color discipline. No illustration,
no decoration, no imitation of any studio's brand.

This file is the single source of the tokens. Each app mirrors them: the admin and listing
page as CSS custom properties (`apps/admin/app/assets/stylesheets/application.css`), the board
as a daisyUI theme (Agent B, after #60).

## Color

Warm, low-chroma, near-print. Every value below is a hex and its WCAG 2.1 contrast ratio
against the background `#FAF8F4`, measured with the standard relative-luminance formula.

| Token | Hex | Ratio vs background | Use |
|---|---|---|---|
| `--bg` | `#FAF8F4` | base | Page background (warm off-white) |
| `--text` | `#1A1A17` | 16.44:1 | Primary text (near-black) |
| `--text-secondary` | `#6A6A61` | 5.15:1 | Secondary text (mid-gray) |
| `--rule` | `#E4E0D8` | 1.24:1 | 1px hairline rules (decorative, not text) |
| `--accent` | `#1F5C3D` | 7.45:1 | The one accent (deep green): links, the availability figure |

All text colors clear WCAG AA for normal text (4.5:1). `--rule` is a non-text hairline, so the
text threshold does not apply to it.

### The five statuses

A muted, colorblind-safe set: each hue differs from the others in both hue and lightness, and
the UI always pairs the color with its text label, so color is never the only signal. Each is
AA as text on the background.

| Status | Token | Hex | Ratio vs background |
|---|---|---|---|
| `occupied` | `--status-occupied` (ink) | `#2E3A46` | 10.94:1 |
| `on_notice` | `--status-on-notice` (ochre) | `#8A5A12` | 5.57:1 |
| `on_notice_rented` | `--status-on-notice-rented` (teal) | `#246E73` | 5.57:1 |
| `vacant_rented` | `--status-vacant-rented` (sage) | `#516B48` | 5.58:1 |
| `vacant_available` | `--status-vacant-available` (terracotta) | `#9C4A2F` | 5.77:1 |

## Type

- **Family:** the system font stack, no web fonts:
  `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif`.
- **Scale** (1.2 minor third, rounded): `0.78rem, 0.875rem, 1rem, 1.25rem, 1.5rem, 2rem, 2.75rem`.
- **Headings:** tight (`line-height: 1.1`, `letter-spacing: -0.01em`), weight 600.
- **KPI numerals:** large and light (weight 300), `font-variant-numeric: tabular-nums` so figures
  align in columns and the eye reads change, not reflow.
- **Body:** `line-height: 1.55`; measure capped near 68 characters.

## Space and shape

- **Spacing scale (8px):** `4, 8, 16, 24, 32, 48, 64` px, exposed as `--space-1`..`--space-7`.
- **Whitespace is the layout.** Separate with space and thin rules, not boxes, borders or
  shadows. The only border is the 1px `--rule` hairline.
- **Corner radius:** `2px` maximum (`--radius`), used sparingly (status pills, inputs).
- **Rules:** `1px solid var(--rule)`. No drop shadows anywhere.

## Tables and numbers

- Numeric columns are right-aligned with tabular figures; text columns left-aligned.
- Rows are separated by a single hairline, no zebra striping, no cell borders.
- Column headers are secondary-color, small caps weight 600, with a hairline under the header row.

## Why these choices

Restraint reads as considered. Warm off-white and near-black lower the glare of pure
black-on-white; one deep-green accent keeps attention where it belongs (a link, the live
availability count). The status palette is chosen for difference under color-vision deficiency
and is always labeled, so the board stays legible in the GIF and to every reader.
