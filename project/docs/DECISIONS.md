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

*(Added 2026-07-11)* (d) A test script with a **parse error** loads as a
non-null GDScript whose `new()` hard-aborts the runner's coroutine — the
run then idles forever with `quit()` unreached (observed as a ~30-minute
hang at ~0% CPU). The runner now rejects scripts where
`can_instantiate()` is false instead of calling `new()`.

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

## 2026-07-11 — Early web export + GitHub Pages hosting for pre-alpha

A Web export preset (`project/export_presets.cfg`) is committed ahead of
Milestone 6 so playtesters can run the current build in a browser with zero
setup. Per the §3 gotcha it is a **single-threaded** export
(`variant/thread_support=false`) — required on static hosts like GitHub
Pages, which send no cross-origin-isolation headers. Export templates
4.7.stable match the pinned editor. The build itself stays out of `main`
(`build/` is gitignored); it is published on the `gh-pages` branch at
https://charles-hood.github.io/fytr9/ and re-exported/pushed manually per
milestone. The raw wasm is ~35 MB (≈10 MB over the wire); the plan's <30 MB
compressed Web target remains a Milestone 6 acceptance gate, not something
this pre-alpha build must already meet. M6's full export/audit criteria
(checksums, notices, platform acceptance) still apply when release
candidates start.

## 2026-07-11 — Play URLs: github.io is the living build, rockofpages is a snapshot

https://charles-hood.github.io/fytr9/ (gh-pages) is the living build and the
canonical README/playtester link, re-exported and pushed per milestone.
https://fytr9.rockofpages.com/ (Charles's own server) is a deliberate
point-in-time snapshot tied to a blog post — it is NOT updated per milestone
and README must not describe it as the current build.

## 2026-07-10 — Placeholder pause behavior

Until the real pause flow lands (Milestone 3), `pause` in the placeholder game
session returns to the title screen so the boot → title → session → title loop
is walkable end to end. *(Superseded 2026-07-11: M3 ships a real pause
overlay — see the M3 scope entry below.)*

## 2026-07-11 — Milestone 3 scope boundaries and decisions

Where M3 tasks left details unspecified, the boundaries (per §0.9
simplest-consistent rule):

- **The M3 run ends after wave 5** with a "SECTOR CLEARED" report. The §6.2
  post-5 formulas and endless progression arrive in Milestone 4 with the
  finite-encounter-budget work. All-Settlers-lost still ends the run with a
  game-over overlay (the §4.6 PLANET_COLLAPSE branch is M4, as recorded in
  the M2 entry).
- **Waves 1–5 spawn Snatchers only.** The §6.2 Mine Layer / Brood Pod /
  Ravager columns and the Interceptor timer are authored in
  `resources/encounters/waves_01_05.tres` now but spawn from M4, when those
  enemies exist.
- **Death releases carried Settlers into FALLING at the craft's position** —
  "safely resolve any carried Settler" (§4.4 step 3) is interpreted to mirror
  the explicit failed-hyperspace rule (§4.3). A low-altitude death therefore
  usually returns the Settler safely; a high one risks LOST. No free rescue.
- **Respawn is in place** (same ring x, fixed safe altitude), after a 2 s
  pause, with the §4.4 clearing: hostile projectiles inside the 320 px safety
  radius are removed and enemies inside it are pushed to its edge.
- **Ramming kills both.** Player–enemy contact destroys the enemy (scoring
  normally) and the ship. The plan is silent; this matches the classic and
  avoids a free bump-through.
- **Snatcher shot speed 240 px/s, range-gated at 900 px** (§5 gives cadence
  2.0 s but no speed; 240 is dodgeable at player speed 400). Off-screen
  snatchers beyond the range gate hold fire so the ring isn't flooded.
- **Catch forgiveness** (§6.4 Large/Standard/Tight) is a catch-radius
  multiplier: 1.35 / 1.0 / 0.8.
- **High-score foundation is in-memory** in SaveService (top ten per §6.4
  table: assisted/canonical/ace), shown on the HUD and the run report. Disk
  persistence with the full corruption/migration behavior is Milestone 5, as
  planned.
- **Pause is a real overlay now** (ESC/P toggles, tree-paused; Q/L quits to
  title from it). The M5 menu pass replaces the placeholder visuals. The
  gamepad-disconnect auto-pause arrives with the M5 options work (§8).
- **Difficulty is selected on the title screen** (left/right), stored in
  AppState per §10.2; the pre-M5 title screen shows it inline.

## 2026-07-11 — External M3 code review (Codex): all four findings adopted

An independent Codex review of the M3 slice (report:
`fytr9-milestone-3-code-review-qa-2026-07-11.md`, repo root, untracked)
produced 2 medium / 2 low findings; all four were accepted as real defects
against the plan's own contracts and fixed the same day:

1. **Hyperspace fallback (§4.3, medium):** when all 32 random candidates
   fail, the destination now comes from a deterministic 60×4 sweep of the
   whole band taking the maximum-clearance point (no extra RNG), instead of
   "least-bad random candidate" which could sit inside a hull. Under the §14
   hostile caps the sweep maximum always clears hull contact; a saturated-
   field test pins that floor.
2. **Encounter-schedule determinism (§6.3, medium):** WaveDirector now
   pre-rolls the entire wave schedule (delays + authored positions) at
   construction, making encounter RNG consumption a pure function of
   (run seed, wave number). The old rejection sampling consumed a
   player-position-dependent number of draws. Spawn safety (§5) became a
   deterministic RNG-free shift to the safety-radius edge; the concurrency
   cap defers wall-clock timing but never changes draws or order.
3. **Reward at ship cap (§4.3/§4.4, low):** a score threshold crossed while
   at 5 ships now awards nothing — no bomb, no EXTRA SHIP banner. The plan
   ties the bomb to "whenever an extra ship is awarded"; a blocked ship
   award is not an award. (If M6 balance wants consolation bombs, that's a
   deliberate change, not a default.)
4. **Harness positive completion (low):** the runner fails when a test
   directory is missing/unreadable or when zero suites/checks ran, and
   run_checks.sh additionally requires exactly one non-empty `PASS:` summary
   and an engine banner in the boot stage — a green exit code alone no
   longer proves a run happened.

The review's M4 watch item (whole-field `enemies.size()` feeding the
Snatcher-specific concurrency cap) is annotated at the call site and must be
resolved when the roster diversifies. Review process note: this was the
open-ended discovery pass; its findings are now part of the acceptance
surface above, and follow-up review rounds should be scoped to this rubric
plus regressions rather than re-opened territory.

## 2026-07-11 — External M3 review round 2 (GLM): triage and review freeze

A second independent review (report: `fytr9-code-review-qa-2026-07-11.md`,
repo root, untracked) found 0 blockers, 2 should-fix, 4 nits, 3 test gaps.
Disposition:

- **Fixed — scanner/HUD overlap (should-fix):** the high-score and
  difficulty labels sat entirely under the scanner's 85%-opaque rectangle;
  both moved to the right column under the population readout.
- **Documented, not coded — Pulse Bomb y-check (should-fix):** the viewport
  is the full 720px logical height and every hostile lives inside the
  playable band within it, so an x-only window IS "the visible viewport";
  a y check would be dead code. Comment added at the detonation site;
  revisit only if an M4+ enemy can exist outside the vertical viewport.
- **Fixed — rebase one-frame glitch (mis-tiered as nit; real rendering
  bug):** `_maybe_rebase()` now runs before `_place_entities()` and the
  camera update, so a rebase tick renders entities against the shifted
  anchor instead of a world width off-screen; the rebase test now asserts
  entity placement through a full tick.
- **Removed — dead `target_dummy` scene/script** (M1 scaffolding,
  unreferenced since M2).
- **Skipped — duplicate edge arrows:** identical warnings on the same side
  overlap pixel-for-pixel, so there is no visible defect to fix.
- **Deferred to M4 (already annotated) — whole-field count vs the Snatcher
  concurrency cap.**
- **Test gaps closed:** multiple simultaneous carries (stacking + release
  on death), catch-radius difficulty scaling applied in the catch check,
  and standalone instantiation of the remaining scenes.

**Review freeze:** this was the second open-ended discovery pass (after the
Codex round). Per the discovery→closure rule, the rubric is now frozen:
subsequent review rounds check the plan contracts + both review reports'
finding classes + regressions reachable from changes — new territory is out
of scope, and review of a change stops after two clean passes.

## 2026-07-11 — Idle-wave playtest note: measured, and answered with M3 pressure

Frank's pre-alpha report said an idle player's wave can "self-resolve in
under ten seconds." Reproduced headlessly against the M2 build across eight
seeds: an idle wave actually ends in **55–60 s** (all four Snatchers escape
serially under the abduction cap), but the substance stands — it ended in
"WAVE COMPLETE" with the clear bonus and 6/10 survivor bonuses for doing
nothing. The M3 systems close this: Snatchers now fire aimed shots, terrain
and contact are lethal, and lives are finite, so an idle Pilot run ends in
game over within seconds-to-a-minute instead of quietly banking wave bonuses
(regression-tested in `test_snatcher_fire.gd`). Waves cleared by escapes
remain a legal §6.1 exit — the M4 Interceptor is the designed anti-stall for
players who fight but won't finish.
