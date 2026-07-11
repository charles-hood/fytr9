# FYTR9

A fast, single-player panoramic rescue shooter: pilot the experimental FYTR-9
craft around a continuously looping planet, destroy hostile aircraft, and
rescue Settlers from abduction.

The authoritative implementation plan is [`fytr9-plan-v4.md`](fytr9-plan-v4.md).

## Engine (pinned)

- **Godot 4.7.stable.official.5b4e0cb0f** (installed via Homebrew cask `godot` 4.7)
- Renderer: **Compatibility** (`gl_compatibility`)
- Language: GDScript only
- Logical resolution: 1280×720, 16:9
- **Export templates:** download the matching **4.7.stable** templates before
  Milestone 6 (Editor → Manage Export Templates). An editor/template version
  mismatch is a silent-failure trap.

## Repository layout

- `project/` — the Godot project (open this directory in the editor)
- `project/docs/DECISIONS.md` — recorded implementation decisions
- `project/docs/BACKLOG.md` — post-v1 ideas (never built in v1)
- `project/licenses/` — asset manifest and third-party notices
- `run_checks.sh` — runs the full test suite plus a headless boot smoke test

## Verified CLI commands

Verified against this exact build's `godot --help` output (per plan §12):
`--headless`, `--path`, `--script`, `--quit-after <int>`, `--check-only`, and
`--import` are all present in 4.7.stable.official.5b4e0cb0f.

Run the automated test suite (headless, dependency-free runner):

```bash
godot --headless --path project --script res://tests/test_runner.gd
```

Boot smoke test (boots the real main scene with autoloads, quits after 3 frames):

```bash
godot --headless --path project --quit-after 3
```

One-time import (regenerates `project/.godot/`; rerun after adding importable assets):

```bash
godot --headless --path project --import
```

Run everything at once:

```bash
./run_checks.sh
```
