# Product

## Register

product

## Users

The primary user is the owner of this Hyprland laptop. They use Caelestia Control Center to change everyday desktop and hardware preferences without editing configuration files or remembering commands.

## Product Purpose

Caelestia is the desktop shell and settings surface for this machine. Settings should expose the effective system behaviour, persist locally, react to hardware state such as AC power and monitor connections, and remain understandable without Linux power-management knowledge. The Task Manager extends this control room with a clear view of running processes and startup behaviour.

## Brand Personality

Calm, direct, and coherent. New controls should feel native to the existing Material-derived Caelestia interface and use its established components, tokens, terminology, and interaction patterns.

## Anti-references

Do not visually imitate Windows or introduce a second design language merely because a workflow is Windows-like. Avoid decorative controls, hidden system side effects, duplicated power handlers, and settings that appear saved but are not the source of truth.

## Design Principles

1. Show choices in the context where they apply, especially AC versus battery.
2. Keep one clear owner for each system behaviour to prevent conflicting actions.
3. Preserve safe laptop defaults and existing docked-monitor behaviour.
4. Reuse Caelestia components and tokens so settings remain predictable.
5. Persist changes immediately and make the visible selection match effective behaviour.

## Accessibility & Inclusion

Keep labels translatable with `qsTr`, preserve the existing theme contrast and type scale, use familiar labels for power actions, and avoid relying on color alone to indicate the selected option. Inherited animations and controls should continue to respect the shell's existing accessibility and motion settings.
