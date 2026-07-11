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

## 2026-07-10 — Seam architecture: player-anchored continuous scene space

§10.3 requires singular simulation entities, all wrapped math through
RingWorld, and no physics-enabled seam duplicates. Implementation chosen:
every entity keeps a normalized ring position (`sim_x` ∈ [0, W)); the
player's node position is *continuous* (unwrapped) and anchors the scene;
each physics tick GameWorld places every other entity at
`player_scene_x + wrapped_delta_x(player.sim_x, entity.sim_x)`.

Consequences:
- Scene-space geometry is faithful within ±W/2 of the player, so rendering
  and physics-adjacent interactions cross the seam with no proxy nodes, no
  duplicate collisions, and no edge triggers — the cases §12's manual seam
  checks worry about can't arise structurally.
- Since W (3840) is 3 viewports, no entity can ever need to appear twice on
  screen, so per-entity visual proxies (§10.3's fallback technique) are
  unnecessary; terrain — the one object spanning the whole ring — is drawn
  windowed by sampling the wrapped profile (TerrainView), which is the same
  proxy idea expressed as sampling.
- The anchor's continuous x is rebased by a whole number of laps once it
  exceeds ±16 laps, shifting player and camera in the same tick (invisible,
  float-precision-safe; verified by test).

## 2026-07-10 — Player-shot hits: swept wrapped-math check

§4.3 requires CCD "or an equivalent swept check". Player shots resolve hits
via an explicit swept segment test in ring space each fixed step (start→end
along flight direction, wrapped, against target radius). This is
deterministic, headless-testable, and immune to seam/tunneling artifacts.
The §10.5 collision layers are still configured on all Area2D actors —
engine-side overlap (player hurtbox vs enemies etc.) arrives with the real
roster in M2+.

## 2026-07-10 — M1 terrain contact is a rebound clamp

Lethal terrain collision (§4.2 Pilot/Ace) needs death/respawn flow, which is
Milestone 3. Until then the flight lab clamps the player just above the
surface (Cadet-style rebound) so terrain shape can be felt without a death
loop. Revisit at M3.

## 2026-07-10 — §4.2 values re-derived viewport-relative at 1280×720

Per §4.2/M1, the inherited pixel values translate to, at 1280×720:
- Screen-crossing time: 1280 / 400 = **3.2 s** at max speed.
- World-lap time: 3840 / 400 = **9.6 s**.
- Full reversal: brake phase 0.15 s + rebuild 0.45 s = **0.6 s** (in range).
- Release coast from max: 400 / 500 = **0.8 s**.
- Camera look-ahead: 0.22 × 1280 = **281.6 px**, velocity-scaled.
- Arc Lance: 800 px/s crosses a screen in 1.6 s; closing speed over a
  fleeing target is 400 px/s (§4.2's own watch item: only 2× player speed —
  **watch in feel test**, bump projectile_speed if sluggish).
These are structurally sound; final lock still requires the human feel pass
(M1 exit criterion "enjoyable for five minutes"), which automation cannot
provide.

## 2026-07-10 — Test-runner readiness gotcha

Nodes added to the tree during a SceneTree script's `_initialize` never
receive NOTIFICATION_READY (no @onready wiring), and GDScript runtime
errors abort a test method silently. The runner therefore (a) starts tests
only after the first processed frame, (b) fails any test method that
records zero assertions, and (c) run_checks.sh fails on any SCRIPT ERROR in
test output even if the summary says PASS.

## 2026-07-10 — Published publicly; external pre-alpha feel check

The repo is public at https://github.com/charles-hood/fytr9 (Charles's call:
easiest for playtesters, code is MIT anyway). The Milestone 1 exit criterion
"flying, reversing, shooting, and crossing the seam remain enjoyable for five
minutes" is delegated to human playtesting: Charles plus one external
pre-alpha tester (Frank). Milestone 2 starts after that verdict; expect
§4.2 balance values to move in response — Arc Lance closing speed is the
flagged suspect (see the value-derivation entry above).

## 2026-07-11 — Milestone 2 scope boundaries

Where M2 tasks touch systems that belong to later milestones, the boundary
is drawn as follows (per §0.9 simplest-consistent rule):

- **Snatcher aimed shots** (§5: every 2.0 s) are deferred to Milestone 3 —
  there is no player death until lives/respawn exist, so enemy fire would be
  dead code. The Snatcher's abduction behavior is complete.
- **Ravager spawn on escape** is deferred to Milestone 4 (its roster
  milestone). The Settler MUTATED transition, population loss, and the
  escaped-carrier despawn are fully implemented and tested; M4 wires the
  transformed enemy into the escape event.
- **All Settlers lost ends the M2 run with a game-over overlay.** The real
  `PLANET_COLLAPSE`/extinction branch (§4.6) is Milestone 4 content and will
  replace that run-end path.
- **Run-end is an in-session overlay** (fire = instant retry, esc = title);
  the full game-over report scene with score tables is Milestone 5.

## 2026-07-11 — Wave-clear gate includes player-carried Settlers

§6.1 blocks wave completion on "unresolved Settler abduction/catch
transitions." Interpreted to include CARRIED_BY_PLAYER: a wave cannot end
while a Settler dangles from the craft — the player resolves it by entering
the drop band. TARGETED, CARRIED_BY_ENEMY, and FALLING block likewise;
DELIVERED does not.

## 2026-07-11 — Multiple simultaneous player carries allowed

The plan speaks of "a carried Settler" but doesn't forbid catching another
while carrying (the classic handles multiples). Simplest consistent choice:
allow it; carried Settlers stack below the craft at a fixed spacing. Revisit
only if playtesting shows it trivializes rescues.

## 2026-07-11 — Grab and carry offsets must be equal

Found by the integration suite: with grab_offset_y (12) smaller than
carry_offset_y (22), the grab teleported the Settler 10px *down* into the
terrain, so a released Settler "landed" instantly and could never be caught.
Both offsets are now 22 and the balance class documents that they must
match — the Settler is lifted exactly from where it stood.

## 2026-07-10 — Placeholder pause behavior

Until the real pause flow lands (Milestone 3), `pause` in the placeholder game
session returns to the title screen so the boot → title → session → title loop
is walkable end to end.
