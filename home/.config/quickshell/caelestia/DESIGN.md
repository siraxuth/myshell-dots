---
name: Caelestia
description: A focused control room built from calm, tonal Material surfaces.
colors:
  rose-primary: "#ffb0ca"
  rose-primary-container: "#6f334a"
  warm-secondary: "#e2bdc7"
  peach-tertiary: "#f0bc95"
  surface: "#191114"
  surface-container: "#261d20"
  surface-container-high: "#31282a"
  on-surface: "#efdfe2"
  on-surface-variant: "#d5c2c6"
  outline: "#9e8c91"
  error-container: "#93000a"
  success-container: "#374B3E"
typography:
  display:
    fontFamily: "Rubik"
    fontSize: "28px"
    fontWeight: 600
  title:
    fontFamily: "Rubik"
    fontSize: "18px"
    fontWeight: 600
  body:
    fontFamily: "Rubik"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: "Rubik"
    fontSize: "11px"
    fontWeight: 500
  mono:
    fontFamily: "CaskaydiaCove NF"
rounded:
  small: "12px"
  normal: "17px"
  large: "25px"
  full: "1000px"
spacing:
  small: "7px"
  normal: "12px"
  large: "20px"
components:
  button-primary:
    backgroundColor: "{colors.rose-primary}"
    textColor: "{colors.surface}"
    rounded: "{rounded.full}"
    padding: "10px 15px"
  button-tonal:
    backgroundColor: "{colors.rose-primary-container}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.full}"
    padding: "10px 15px"
  field-search:
    backgroundColor: "{colors.surface-container-high}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.small}"
    padding: "10px 12px"
  card-surface:
    backgroundColor: "{colors.surface-container}"
    textColor: "{colors.on-surface}"
    rounded: "{rounded.large}"
    padding: "20px"
---

# Design System: Caelestia

## Overview

**Creative North Star: "The Focused Control Room"**

Caelestia is a desktop toolset for quick, confident decisions. Its interface uses compact groups, clear labels, and the wallpaper-aware Material palette already active in the shell. Tonal surfaces create depth while rounded edges and consistent spacing keep the many control panels related.

Motion is restrained and state-led: a control responds when it changes, while the surrounding layout stays still. The visual system rejects Windows imitation and a second design language. Its density favors useful information, with enough spacing to scan process names, system readings, and startup sources at a glance.

**Key Characteristics:**
- Live Material roles with warm default fallback tones.
- Tonal depth and fine outlines instead of decorative shadows.
- Compact, keyboard-friendly layouts with clear state labels.

## Colors

The live wallpaper palette drives all surfaces; the hex values below are the current fallback values in `Colours.qml`.

### Primary
- **Rose Primary** (#ffb0ca): Main selected and high-emphasis actions.
- **Rose Container** (#6f334a): Primary tinted containers and active tonal states.

### Secondary and Tertiary
- **Warm Secondary** (#e2bdc7): Supporting accents and secondary selected controls.
- **Peach Tertiary** (#f0bc95): Occasional attention for elevated readings.

### Neutral
- **Night Surface** (#191114): Deepest shell background.
- **Warm Surface Container** (#261d20): Main panel surface.
- **Raised Warm Surface** (#31282a): Grouped rows and cards.
- **Soft Rose Ink** (#efdfe2): Main text.
- **Muted Rose Ink** (#d5c2c6): Supporting labels and metadata.
- **Warm Outline** (#9e8c91): Borders and separators.
- **Error Container** (#93000a): Error feedback.
- **Forest Success Container** (#374B3E): Positive status chips.

**The Live Palette Rule.** Use `Colours.palette` roles in QML. Hex values here describe fallback colors, not replacements for live theme bindings.

## Typography

**Display Font:** Rubik (system sans-serif fallback)
**Body Font:** Rubik (system sans-serif fallback)
**Label/Mono Font:** Rubik for labels; CaskaydiaCove NF for fixed-width process details when useful.

**Character:** Rubik is friendly and compact at the shell's small sizes. Weight and color establish hierarchy without adding another typeface for decoration.

### Hierarchy
- **Display** (DemiBold, 28px): Main tool heading.
- **Headline** (DemiBold, 18px): Section and prominent value headings.
- **Title** (Medium, 13px): Process and startup entry names.
- **Body** (Regular, 13px): Main labels and explanations.
- **Label** (Medium, 11–12px): Compact metadata and short column labels.

## Elevation

Caelestia uses tonal layering rather than drop shadows. The panel sits on `m3surfaceContainer`; grouped rows use `m3surfaceContainerHigh`; selected controls use a tinted container. Thin outline roles separate surfaces where tone alone is insufficient. State transitions follow the shell's shared `Anim` curves and durations.

**The Tonal Depth Rule.** Keep surfaces flat at rest and communicate hierarchy through Material surface roles, a 1px outline, and component spacing.

## Components

### Buttons
- **Character:** Direct and tactile, with clear emphasis levels.
- **Shape:** Shared shell radius, typically a 12px capsule for text actions.
- **Primary:** `TextButton.Filled` uses `m3primary` and its matching on-color.
- **Secondary:** `TextButton.Tonal` uses a secondary container.
- **Ghost:** `TextButton.Text` stays transparent and reserves the primary role for its label.
- **Hover / Focus:** Use the shared `StateLayer`; retain keyboard focus visibility.

### Chips
- **Style:** Compact rounded tonal surfaces with a readable label.
- **State:** Pair color with explicit text such as “Running” or “Protected”.

### Cards / Containers
- **Corner Style:** `Tokens.rounding.large` (25px) for the main panel; `small` (12px) for rows.
- **Background:** `m3surfaceContainer` for a panel and `m3surfaceContainerHigh` for contained rows.
- **Shadow Strategy:** No shadow; use tonal depth and a 1px `m3outlineVariant` border.
- **Internal Padding:** `Tokens.padding.large` (15px) for panel content, `normal` (10px) for rows.

### Inputs / Fields
- **Style:** `StyledTextField` with a tonal background and 12px corner radius.
- **Focus:** Shared control focus and cursor styling; preserve readable contrast.
- **Error / Disabled:** Use error-container feedback and visibly disable unavailable controls.

### Navigation
- **Style:** Horizontal tonal tabs for short tool sections.
- **Active:** Filled or tonal state with readable text; inactive tab remains available as a text action.
- **Keyboard:** Tab focus and direct keyboard activation remain available.

### Process and Startup Rows
- Use one readable primary name and one elided secondary command or source.
- Align numeric process readings to the right.
- Place a live-state badge next to the startup switch; disable switches for unmanaged units.

## Do's and Don'ts

### Do:
- **Do** bind surfaces and text to `Colours.palette` roles so wallpaper themes remain live.
- **Do** use `Tokens.rounding` and `Tokens.spacing` for consistent corners and rhythm.
- **Do** use accessible labels and a visible textual state alongside color.
- **Do** request graceful process shutdown before exposing a separate force action.

### Don't:
- **Don't** visually imitate Windows or introduce a second design language.
- **Don't** use fixed palette colors for themed QML surfaces.
- **Don't** use shadows to create depth in otherwise tonal shell panels.
- **Don't** show an unavailable startup source as an active switch.
