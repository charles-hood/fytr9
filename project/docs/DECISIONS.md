# Implementation decisions

Decisions made where the plan (`fytr9-plan-v4.md`) left a detail unspecified,
per plan §0.9. Newest entries at the bottom.

## 2026-07-10 — Godot project lives in `project/`, repo docs at root

The plan's §12 example command (`godot --headless --path project ...`) implies
the Godot project sits in a `project/` subdirectory. Adopted: `project/` is
`res://`; the repo root holds the plan, README, LICENSE, `.gitignore`, and
`run_checks.sh`. `docs/` and `licenses/` live inside `project/` as shown in
the §10.1 layout.

## 2026-07-10 — Pinned engine build

Godot **4.7.stable.official.5b4e0cb0f**, installed via Homebrew cask `godot`
(4.7). Verified `--headless`, `--path`, `--script`, `--quit-after <int>`,
`--check-only`, and `--import` against this build's `--help` (plan §12).

## 2026-07-10 — Project license

MIT for all project code (plan §19 recommendation), `LICENSE` at repo root.
The license for original art/audio (CC0 vs CC BY 4.0) will be decided at the
Milestone 5 asset pass, when original assets first ship.

## 2026-07-10 — Scaling: `canvas_items` stretch + `keep` aspect

Plan §3 says "prefer integer scaling, filtered fallback where impossible."
Godot's `integer` scale mode letterboxes heavily at non-multiple window sizes,
and FYTR9's art is procedural vector shapes (§9), not pixel sprites — vector
canvas items rescale crisply at fractional factors. Adopted: stretch mode
`canvas_items`, aspect `keep` (letterbox/pillarbox preserves equal gameplay
visibility across ratios, §3). This is the "filtered fallback" case; revisit
only if a pixel-art pass ever happens.

## 2026-07-10 — Earlier plan drafts gitignored

`fytr9-plan-unified/final/v3.md` and the `claude/`, `codex/`, `deepseek/`,
`glm/` scratch directories are reference material from the planning rounds,
not part of the game. They stay on disk but are gitignored; v4 alone is
committed as source of truth (§17).

## 2026-07-10 — Input deadzones

Movement actions use deadzone 0.25; button-like actions that also accept a
trigger axis (fire, pulse_bomb) use 0.5. The user-configurable gamepad
dead-zone option arrives in Milestone 5 (§8) and will feed these actions.

## 2026-07-10 — Placeholder pause behavior

Until the real pause flow lands (Milestone 3), `pause` in the placeholder game
session returns to the title screen so the boot → title → session → title loop
is walkable end to end.
