# MAD Installer — Design Tokens (v3 — Professional White / Premium Minimal)

The single source of truth for MAD Installer's visual language, implemented
in `calamares/branding/mad/branding.desc` (`style:` keys),
`calamares/branding/mad/stylesheet.qss`, and `slideshow.qml`.
Interactive mockups for all ten screens: the design prototype delivered with
this document (`docs/DESIGN-PROTOTYPE.md`).

Previous themes: dark charcoal v2 is preserved in `docs/stylesheet-dark-v2.bak`
and `docs/slideshow-dark-v2.bak`; v1 (Echo teal/orange) was echo-install's
inherited styling.

## Palette

| Token | Value | Used for |
| --- | --- | --- |
|  `bg` | `#F5F6FA` | Window / page background |
| `surface` | `#FFFFFF` | Cards, inputs, sidebar, dialogs |
| `text` | `#171923` | Primary text |
| `text2` | `#737987` | Secondary text, captions |
| `accent` | `#6952E8` | Primary accent — buttons, selection, progress |
| `accent2` | `#927DFF` | Hover accent, focus rings |
| `success` | `#20C987` | Success states |
| `border` | `#E8EAF0` | Subtle borders, tracks |
| `soft` | `#F0EDFF` | Soft highlight fill (selected cards, focus glow) |
| `danger` | `#E5484D` | Destructive actions, errors |

Accent derivation: the MAD purple (`#6952E8`) is the installer's own accent;
the Echo OS mark keeps its original colors (black `#0b0b0b` + teal `#019099`)
and is never recolored.

## Logo usage

- Master asset: `echo-mark.svg` (verbatim copy) — used on all light surfaces
  at native colors (window icon, sidebar logo, welcome hero, slideshow).
- No contrast variants are needed on the white theme; `echo-mark-light.svg`
  remains for any future dark surface.
- Never recolor, stretch, crop, or outline the mark. Clear space: 25% width.

## Typography

- Inter (prototype) → system font stack in the real installer (Plasma
  default; no custom font is shipped, matching the installed desktop).
- Hierarchy: page title ≈ 24–34px bold (weight 700–800 in prototype),
  section titles 600, body/descriptions 400–500, secondary labels small in
  `text2`. Line height ≥ 1.55 for descriptions.

## Shared layout (v3.1 — no sidebar, bottom stage indicator)

Per the approved Fortect-style structure change (2026-10-31):

- **The left step sidebar is removed** — `branding.desc` sets
  `sidebar: none` in the real installer; the prototype drops it entirely.
- Every screen is a **floating white card** (radius 22, soft shadow) on the
  `bg` surface: content section left, rounded illustration panel right.
- The **bottom stage indicator** (numbered circles 1-2-3, connecting lines,
  labels *Welcome / Configure Your System / Ready to Install*) sits below
  the card on every screen. In the engine, Calamares' bottom Back/Next
  navigation widget is the closest supported equivalent; a QML stepper
  cannot reflect step state on 3.4.2 (verified).

## Geometry

| Token | Value |
| --- | --- |
| Card radius | 22px (prototype); installer window is managed by the WM |
| Card radius | 16px |
| Control radius | 10–12px |
| Input height | 40–44px |
| Page padding | 52px horizontal (34px top) |
| Shadows | soft, purple-tinted: `0 12px 28px -12px rgba(105,82,232,.4)` on selection, neutral large shadows on the window |

## Controls

- **Primary action** (Continue / Install Now): `accent` fill, white text,
  radius 12, hover `accent2`, pressed `#5743C9`; disabled = `border` fill +
  `text2`.
- **Secondary action** (Back): white fill, `border` outline, hover `soft`.
- **Destructive** (Cancel): transparent, `text2` text, `danger` on hover.
- **Inputs**: white fill, 1.5px `border`, `accent2` 2px focus ring,
  radius 10.
- **Cards** (modes/packages/disks): white, 1.5px `border`, hover lifts with
  purple shadow; selected = `accent` border + `soft` gradient fill + check.
- **Progress**: `border` trough, `accent` chunk, radius 6, semibold % text.
- **Step list** (Calamares sidebar): white background, `text2` text,
  current step = `accent` fill with white text (via `branding.desc`
  `style:` keys — the delegate is not QSS-stylable).

## Motion

- Screen fade/translate 450ms ease; card hover lift; gentle illustration
  float (7s loop); progress ring animated. All decorative motion is
  disabled under `prefers-reduced-motion` (implemented in the prototype;
  the widget installer follows the platform animation policy).

## Verified constraints (Calamares 3.4.2) — implementation boundary

Checked against upstream `CalamaresWindow.cpp` + live VM evidence:

- **Implementable directly (integrated):** global QSS theme (all widget
  styling above), sidebar colors via `branding.desc` `style:`, product
  images, window size/placement, slideshow QML.
- **Not expressible on this engine** (prototype-only screens; see
  `docs/DESIGN-PROTOTYPE.md`): the onboarding welcome composition, custom
  3D illustrations, installation-mode cards (screen 04), package selection
  (screen 05), per-stage progress list (screen 09 shows real Calamares
  progress instead). Calamares QML panels receive no step model, and the
  offline unpackfs backend has no package-selection mechanism
  (`packages` module is a no-op by design).
