# FYTR9

A fast, single-player panoramic rescue shooter — pilot the experimental
FYTR-9 craft around a continuously looping neon planet, destroy hostile
aircraft, and rescue Settlers from abduction before they're carried away.

**Status: pre-alpha.** The complete arcade loop is playable — five waves of
Snatchers that shoot back, lives and respawns, Pulse Bombs, risky hyperspace,
three difficulty presets, and instant retry. The full enemy roster and the
planet-collapse cycle are next. Built with Godot 4.7 in GDScript, targeting
Web, Windows, macOS, and Linux.

**▶ [Play it in your browser](https://fytr9.rockofpages.com/)** — no
install needed (desktop browser + keyboard or gamepad).

The authoritative implementation plan is [`fytr9-plan-v4.md`](fytr9-plan-v4.md).

![Milestone 2 rescue slice — an abduction in progress](project/docs/img/rescue-slice.png)

## What's playable right now

The **Milestone 3 complete arcade loop** — a full five-wave run:

- Ten **Settlers** walk the terrain of a seamless looping world (three
  screens wide — crossing the "seam" is invisible by design).
- **Waves 1–5** escalate from 4 to 8 Snatchers, which hunt the nearest
  Settler by shortest wrapped route — and now **fire aimed shots at you**
  every two seconds. Terrain and collisions are lethal (Cadet keeps a
  forgiving terrain rebound).
- **Lives**: 3 ships on Pilot/Ace, 5 on Cadet; extra ship (+1 bomb) at
  10,000 points, then every 50,000, capped at 5. Death releases any carried
  Settler; respawn comes with a cleared safety zone and 1.5 s of grace.
- **Pulse Bomb** (E / K): wipes every enemy and hostile shot on screen.
  Run-level stock — dying does not refill it.
- **Hyperspace** (Q / L): teleports you somewhere safe... usually. 10% of
  jumps destroy the ship on Pilot, 15% on Ace, never on Cadet.
- **Rescue loop** unchanged: shoot the carrier, catch the falling Settler,
  deliver it to the surface. The **scanner** and directional edge arrows
  cover the whole ring.
- **Three difficulty presets** (pick with left/right on the title screen)
  with separate high-score tables, shown on the HUD.
- Clear wave 5 → SECTOR CLEARED; lose every ship or every Settler → GAME
  OVER. Either way: instant retry on fire, pause on ESC/P.

### Quick start

**Easiest:** [play the current build in your browser](https://fytr9.rockofpages.com/).

To run from source instead:

1. Install **Godot 4.7 stable** (macOS: `brew install --cask godot`; other
   platforms: [godotengine.org](https://godotengine.org/download/)).
2. Clone and run:

```bash
git clone https://github.com/charles-hood/fytr9.git
cd fytr9
godot --path project
```

3. On the title screen, press **fire** (Space / J / gamepad south) to launch
   the flight lab.

### Controls (defaults, keyboard or gamepad)

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD or arrows | Left stick or D-pad |
| Fire (Arc Lance) | Space or J | South button or right trigger |
| Pulse Bomb | E or K | West button or left trigger |
| Hyperspace | Q or L | North button or right shoulder |
| Pause | Escape or P | Start |
| Quit to title (while paused) | Q or L | North button or right shoulder |
| Debug overlay | F3 | — |

### Pre-alpha playtest notes — what feedback helps most

- **Danger**: Snatchers now shoot back and terrain kills. Does Pilot feel
  fair — deaths readable, respawns safe, invulnerability window enough?
- **Difficulty spread**: is Cadet genuinely gentle and Ace genuinely mean
  (enemy speed, bomb stock, hyperspace risk, catch radius)?
- **Pulse Bomb & hyperspace**: does the bomb feel worth hoarding? Is
  hyperspace a tempting gamble or a death trap?
- **Wave arc**: waves 1–5 ramp 4→8 Snatchers with up to 2 simultaneous
  abductions late. Where does it tip from calm to frantic?
- **Arc Lance**: does firing while chasing feel punchy or sluggish? (Known
  watch item: shots travel at only 2× ship speed.)
- **Rescue clarity**: when a Settler is taken off-screen, do the banner,
  scanner, and edge arrow get you there in time?
- **Seam**: fly one direction for ~10 s — you'll lap the world. Any visible
  pop, stutter, or double-hit anywhere?
- **Camera**: the view leads your movement direction — too much, too little?

All tuning values live in `project/resources/balance/*.tres` — nothing is
hard-coded.

## Development status

| Milestone | Scope | Status |
|---|---|---|
| 0 — Repository & foundation | Project, input, tests, docs, licenses | ✅ done |
| 1 — Flight laboratory | Ring world, flight model, Arc Lance, terrain, camera, debug | ✅ done (feel check in progress) |
| 2 — Rescue vertical slice | Settlers, Snatcher, catch/carry/return, scanner, first wave | ✅ done |
| 3 — Complete arcade loop | Lives, Pulse Bomb, hyperspace, waves 1–5, difficulty presets | ✅ done |
| 4 — Full roster & planet cycle | Ravager, Mine Layer, Brood Pod, Splinter, Interceptor, planet collapse/restoration | ⬅ next |
| 5 — Presentation, saves, accessibility | Menus, saves, options, art & SFX pass | pending |
| 6 — Balance & release candidate | Playtests, tuning, exports, license audit | pending |

### Next up (Milestone 4 — full enemy roster and planet cycle)

1. Ravager (spawns when a Snatcher escapes — the mutation is already
   tracked), Mine Layer, Brood Pod, Splinter, and the Interceptor
   anti-stall.
2. Finite encounter budgets and the post-wave-5 endless difficulty curve
   (`encounter_rng` deterministic seeding is already in place).
3. `PLANET_COLLAPSE` and the five-extinction-wave cycle per plan §4.6,
   replacing the M3 all-Settlers-lost game over.
4. Performance caps and profile-driven pooling only if measurements demand
   it.

## Engine (pinned)

- **Godot 4.7.stable.official.5b4e0cb0f** (Homebrew cask `godot` 4.7)
- Renderer: **Compatibility** (`gl_compatibility`); GDScript only
- Logical resolution: 1280×720, 16:9
- **Export templates:** download the matching **4.7.stable** templates before
  Milestone 6 (Editor → Manage Export Templates). An editor/template version
  mismatch is a silent-failure trap.

## Repository layout

- `project/` — the Godot project (open this directory in the editor)
- `project/docs/DECISIONS.md` — recorded implementation decisions
- `project/docs/BACKLOG.md` — post-v1 ideas (never built in v1)
- `project/resources/balance/` — all tuning values, as Godot resources
- `project/licenses/` — asset manifest and third-party notices
- `run_checks.sh` — full test suite plus a headless boot smoke test

## Tests and verified CLI commands

Verified against this exact build's `godot --help` output (per plan §12):
`--headless`, `--path`, `--script`, `--quit-after <int>`, `--check-only`, and
`--import` are all present in 4.7.stable.official.5b4e0cb0f.

```bash
./run_checks.sh                # everything: import, tests, boot smoke
godot --headless --path project --script res://tests/test_runner.gd   # tests only
godot --headless --path project --quit-after 3                        # boot smoke
```

Current suite: 19 suites, 1450 checks — ring math, terrain continuity, RNG
stream isolation, flight envelope, Settler state machine and reservations,
Snatcher lifecycle and aimed fire, scanner mapping, scoring rules and reward
thresholds, difficulty presets, high-score tables, Pulse Bomb, hyperspace
safety, death/respawn/invulnerability, simultaneous-event resolution, and
full five-wave runs simulated through the real session scene.

## License

Code is MIT (see `LICENSE`). Asset licensing is tracked in
`project/licenses/` and `project/CREDITS.md`.
