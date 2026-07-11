# FYTR9 — Unified Game Design & Claude Code Implementation Plan (v4)

**Document purpose:** authoritative implementation plan for Claude Code
**Revision:** 4 — fixes from independent ChatGPT and Web Claude reviews of v3; see §17 for full lineage
**Engine:** Godot 4.7 stable, pinned with matching export templates
**Language:** GDScript only
**Renderer:** Compatibility
**Primary targets:** Web, Windows, macOS, Linux
**Project philosophy:** small, original, arcade-focused, deterministic where practical, and built only with free/open tools and properly licensed assets

---

## 0. Instructions to Claude Code

Treat this file as the source of truth.

1. Implement one milestone at a time, in order.
2. Do not add bosses, multiplayer, online services, achievements, power-ups, procedural campaigns, or other unlisted features. Post-v1 ideas go in `docs/BACKLOG.md`, not the code.
3. Use placeholder geometric art and synthesized placeholder audio until the core loop passes its acceptance tests.
4. Put all tuning values in named Godot `Resource` files or clearly centralized configuration files—never scatter unexplained literals through scripts.
5. Add or update automated headless tests for wrapped-world math, radar mapping, Settler state transitions, wave determinism, scoring thresholds, and save recovery.
6. Run the test suite and a headless project boot check after every meaningful change. Verify the exact CLI invocation against the installed Godot build with `godot --help` before relying on it (see §12) and record the working command in `README.md` — flags can differ across releases, so check rather than assume either way.
7. Keep simulation entities singular. Visual seam proxies must never have physics or independently score, collide, fire, or die.
8. Stop at each milestone exit criterion and report:
   - files changed;
   - tests run and results;
   - known limitations;
   - the next milestone's proposed task list.
9. When a design detail is not specified, choose the simplest implementation consistent with the design pillars and record the decision in `docs/DECISIONS.md`. If the idea is a *feature* rather than an implementation detail, it goes in `docs/BACKLOG.md` instead — do not build it now.
10. Do not change engine versions during implementation without a separate migration branch and full regression pass.

---

## 1. Product Vision

FYTR9 is a fast, single-player panoramic rescue shooter. The player pilots the experimental FYTR-9 craft around a continuous horizontally looping planet, destroys hostile aircraft, prevents civilian abductions, catches falling civilians, and returns them safely to the surface.

The game should capture the essential appeal of classic panoramic arcade shooters without copying protected artwork, audio, names, layouts, source code, or exact presentation.

### Design pillars

1. **Immediate flight feel** — movement, reversal, and firing must feel good before content is added.
2. **Protect, not merely destroy** — civilians are the strategic heart of the game.
3. **Whole-world awareness** — the scanner makes threats beyond the viewport actionable.
4. **Readable pressure** — danger escalates through enemy combinations, not opaque rules or inflated health.
5. **Short runs and instant retry** — a typical Pilot run should last roughly 10–20 minutes.
6. **Original presentation** — geometric neon art, original names, original sound design, and independently tuned values.
7. **Controlled scope** — v1 is one polished arcade mode, not a platform.

### Shipped terminology

| Gameplay role | Shipped name |
|---|---|
| Player craft | **Fytr9** |
| Surface civilians | **Settlers** |
| Abductor | **Snatcher** |
| Transformed elite (failed rescue) | **Ravager** |
| Mine-dropping patrol enemy | **Mine Layer** |
| Splitting carrier | **Brood Pod** |
| Fast spawn released by a Brood Pod | **Splinter** |
| Anti-stalling pursuer | **Interceptor** |
| Primary weapon | **Arc Lance** |
| Screen-clearing limited weapon | **Pulse Bomb** |

None of these overlap with Defender's own terminology for the same roles (`Lander`, `Mutant`, `Bomber`, `Pod`, `Swarmer`, `Baiter`). The roster is fully original — simply avoiding all of Defender's names for equivalent roles, rather than judging case-by-case which ones sound generic enough to reuse, costs nothing and needs no borderline calls.

---

## 2. Release Scope

### Included in v1

- One continuous horizontally wrapping world.
- Responsive left/right flight with inertia and bounded vertical movement.
- Forward-firing primary weapon.
- Ten civilians, called **Settlers** in the UI.
- Abduction, mutation, falling, catching, carrying, and safe-return mechanics.
- Six standard enemy roles.
- Pulse Bombs and risky hyperspace.
- Tactical scanner showing the entire world.
- Wave progression and escalating difficulty.
- Planet-loss state, extinction waves, and planet restoration.
- Three difficulty presets with separate local high-score tables.
- Ship lives per difficulty preset (see §6.4), score-based extra lives, local top-ten scores.
- Keyboard and common gamepad support with default bindings for both.
- Pause, title, how-to-play, options, credits/licenses, game-over, and instant retry.
- Original SFX via jsfxr. Music is optional for v1 — see §9.
- Original or verified freely licensed art, fonts, and effects.
- Web and desktop exports.
- Core accessibility: independent volume buses, screen-shake and flash-intensity toggles, reduced-particle mode, gamepad dead-zone configuration, safe pause on gamepad disconnect, and states that read by shape/motion as well as color.

### Explicitly excluded from v1 (see `docs/BACKLOG.md`)

- Bosses.
- Multiplayer or co-op.
- Online leaderboards, accounts, telemetry, or cloud saves.
- Mobile touch controls.
- Power-up drops, weapon upgrades, shields, or RPG progression.
- Multiple planets or campaign mode.
- Achievements, storefront SDKs, paid services, or native extensions.
- Score multiplier/combo system.
- Full keyboard/gamepad **rebinding UI** (default bindings ship in v1; a remap screen, and persisted custom bindings, are a v1.1 feature — see §10.8).
- UI scaling beyond the base layout, and dedicated colorblind palette presets (the base palette already differentiates every state by shape/motion, not color alone, so this is a polish pass, not a blocking requirement).
- An original composed soundtrack (v1 ships with jsfxr SFX and, optionally, one verified CC0 chiptune loop — see §9).
- Full localization, although strings must be externalized for future translation.

---

## 3. Technology and Production Policy

### Engine and project baseline

- Use **Godot 4.7 stable**, not a release candidate or development build.
- Pin the exact editor build and matching export templates in `README.md`.
- Use the **Compatibility renderer** so the same project can export to Web.
- Use GDScript only for the MVP.
- Use Git from the first commit.
- Native logical resolution: **1280 × 720**, 16:9.
- Preserve equal gameplay visibility across aspect ratios. Letterbox or pillarbox rather than revealing extra world space.
- Prefer integer scaling. Use a filtered fallback where integer scaling is impossible.

> **Why 1280×720 and not a low pixel-art canvas:** FYTR9's whole visual identity is procedural vector/geometric art (§9), not pixel art. A 640×360-style low logical resolution only earns its keep when nearest-neighbor-scaled pixel sprites are the art direction; forcing vector shapes through that canvas buys nothing and just adds an unnecessary scaling step. 1280×720 lets vector art render clean at native or near-native resolution on most displays. **Note:** the movement/weapon pixel values in §4.2 were inherited from earlier drafts that used a 640×360 canvas and are explicitly flagged there as placeholders pending viewport-relative validation in Milestone 1 — don't treat them as pre-validated for this resolution.

> **Engine gotchas — get these right from the start:**
> - Use **`Parallax2D`**, not the legacy `ParallaxBackground`/`ParallaxLayer` nodes — deprecated since Godot 4.4, and Godot's own docs now recommend `Parallax2D`. `Parallax2D.repeat_size` tiles the **starfield and other non-colliding background layers** (stars, auroral haze, distant ridges) across the seam. It does **not** own gameplay terrain: the collision terrain and `Terrain.get_surface_y()` data are part of the ring-world simulation (§10.3), rendered as a singular logical height profile through seam-aware visual proxies, not as a repeating parallax layer. Keep those two systems separate.
> - Run all movement/collision in `_physics_process` (fixed timestep), and use `call_deferred` for spawn/despawn triggered from inside physics callbacks.
> - Default to a **single-threaded Web export** for the widest browser compatibility and simplest static hosting; enabling Web threads later requires HTTPS/secure-context and cross-origin-isolation headers, and should be a deliberate later decision, not a default.
> - Download the **matching 4.7 export templates** before Milestone 6 — a version mismatch between editor and export templates is a common silent-failure trap.
> - Verify any specific headless CLI flag against the pinned build's `godot --help` before depending on it in scripts or CI — not because any particular flag is known to be wrong, but because flag availability can shift across engine versions and this project spans several.

### Free/open authoring tools

- Vector art: Inkscape.
- Raster editing: Krita or GIMP.
- Pixel editing when useful: LibreSprite or Piskel.
- Audio editing: Audacity.
- Synthesized effects: jsfxr/sfxr (released under **The Unlicense** — public domain, no attribution required) or original Godot-generated tones exported to audio files.
- Music (optional for v1 — see §9): if pursued, original work made in BeepBox or LMMS; otherwise ship with a single verified CC0 chiptune loop, or no music at all.
- Font: one verified SIL Open Font License family, initially `Press Start 2P` or a more readable OFL alternative.

### Asset policy

Preferred order:

1. Original project assets.
2. CC0/public-domain assets with verified provenance.
3. Compatible OFL, MIT, BSD, Apache-2.0, or CC BY 4.0 assets with fulfilled obligations.
4. Reject NC, ND, "personal use only," ripped, fan-extracted, editorial-only, or unknown-license material.

Maintain:

- `licenses/ASSET_MANIFEST.csv`
- `licenses/THIRD_PARTY_NOTICES.md`
- a copy of every applicable third-party license

For each external asset record local path, title, creator, source URL, retrieval date, exact license, attribution, modifications, and checksum.

Prototype visuals should be original polygons and simple SVGs. Do not delay the core game while searching for asset packs.

---

## 4. Core Game Rules

### 4.1 World

- The world is a horizontal ring.
- Initial world circumference: **3 viewport widths** (3,840 logical pixels at the 1280-wide gameplay resolution).
- Expose the circumference as a balance value and test a range of 2.5–4× viewport widths.
- The playfield wraps only horizontally.
- The player, enemies, projectiles, mines, Settlers, targeting logic, radar, and positional audio all use wrapped-distance math.
- Terrain must join continuously at the seam.
- The camera follows the player with modest look-ahead in the facing/velocity direction.
- Three recognizable terrain regions provide navigation landmarks without changing gameplay rules.

### 4.2 Player movement

- Horizontal input controls thrust and facing.
- Releasing horizontal input applies moderate inertial damping rather than an immediate stop.
- Reversal should be quick enough for combat but visibly animated.
- Vertical movement is direct and slightly slower than maximum horizontal speed.
- The player cannot leave the playable vertical band.
- Terrain collision destroys the ship in Pilot/Ace. Cadet may use a forgiving rebound option.
- Starting values — **placeholders inherited from an earlier 640×360-canvas draft, not yet validated at 1280×720**:

| Parameter | Starting value/range |
|---|---:|
| Maximum horizontal speed | 400 px/s |
| Maximum vertical speed | 260 px/s |
| Time to max horizontal speed | 0.40–0.55 s |
| Full-speed reversal | 0.50–0.70 s |
| Arc Lance cadence | 8–10 shots/s |
| Arc Lance projectile speed | 800 px/s |
| Respawn invulnerability | 1.5 s |
| Hyperspace arrival invulnerability | 0.75 s |
| Camera look-ahead | 20–25% of viewport width |

> **Before locking these values (Milestone 1 task):** re-derive and validate them in viewport-relative terms, not just raw pixels-per-second — specifically, screen-crossing time (how long to cross the 1280-wide viewport at max speed), world-lap time (how long to traverse the full 3,840px world), Arc Lance closing speed relative to player speed (at 400/800 px/s the Lance is only 2× the player's own top speed, which may read as sluggish when firing while moving forward), full-speed reversal time, and camera look-ahead distance. Adjust the pixel values as needed so these feel right at the actual shipped resolution before treating them as final.

### 4.3 Player actions

#### Arc Lance

- Unlimited forward-firing pulse weapon.
- Fires in the ship's facing direction.
- Projectiles use continuous collision detection or an equivalent swept check.
- Cap active player shots through lifetime and visibility rules, not an artificially low arcade-style shot count unless testing proves it improves play.

#### Pulse Bomb

- Start with the stock defined by the selected difficulty preset (see §6.4).
- **Pulse Bombs are a run-level resource and are not refilled when the player loses a ship** — they persist across deaths within a run. Award one additional Pulse Bomb whenever an extra ship is awarded, capped at 5.
- Destroys normal enemies and hostile projectiles in the visible viewport plus a small wrapped seam margin.
- Does not harm Settlers.
- Elite transformed enemies may survive only if later balance testing requires it; default is that all standard enemies die.
- Freeze-frame, flash, and shake effects must respect reduced-flash and reduced-shake settings.

#### Hyperspace

- Teleports the player to a valid random position away from terrain and immediate hostile collision.
- Pilot failure chance: 10%.
- Cadet failure chance: 0%.
- Ace failure chance: 15%.
- A failed jump destroys the active ship with a unique effect.
- A successful jump grants 0.75 seconds of invulnerability.
- A carried Settler remains attached through a successful jump. On failed hyperspace, the Settler begins falling at the origin.
- The destination-selection algorithm must reject unsafe positions **before** applying the random failure roll — never roll failure against a destination that was going to be rejected anyway.
- Hyperspace destination selection and the failure roll draw from `gameplay_rng` (§6.3), not `encounter_rng` — they affect player outcomes, not the authored encounter schedule.

### 4.4 Lives and respawn

- Start with the ship stock defined by the selected difficulty preset (see §6.4 — Cadet 5, Pilot 3, Ace 3).
- First extra ship at 10,000 points; subsequent extra ships every 50,000 points.
- Maximum ship count, including the active ship: 5.
- On death:
  1. stop player control;
  2. play a short explosion;
  3. safely resolve any carried Settler;
  4. clear nearby hostile projectiles and push or delay enemies inside the respawn safety radius;
  5. respawn after a brief pause with invulnerability.
- Game over when no ships remain.

### 4.5 Settlers

Start each normal wave with the surviving population from the prior wave. A newly restored planet starts with 10 Settlers.

Settler states:

1. `SAFE` — walking on terrain.
2. `TARGETED` — reserved by one abductor.
3. `CARRIED_BY_ENEMY`
4. `FALLING`
5. `CARRIED_BY_PLAYER`
6. `DELIVERED` — brief protected state before returning to `SAFE`.
7. `LOST`
8. `MUTATED` — removed as a Settler and responsible for a transformed enemy.

Rules:

- Only one enemy may own or reserve a Settler at a time. Reservations are owned centrally by `SettlerCoordinator`; no actor may claim a Settler directly.
- A Snatcher seeks the nearest available Settler using shortest wrapped distance.
- If the Snatcher reaches the upper escape boundary, the Settler is lost and the Snatcher transforms into a Ravager.
- Destroying a carrying Snatcher releases the Settler into `FALLING`.
- The player catches a falling Settler by overlap.
- A carried Settler hangs below the craft with a clear visual indicator.
- Carrying does **not** reduce ship speed in v1.
- Flying within the safe drop band above terrain returns the Settler to `SAFE`.
- Low-altitude unsupported falls may survive; higher impacts cause `LOST`.
- Settler loss must trigger an audio cue, scanner cue, and directional screen-edge warning.
- Settler delivery grants score and a small bomb-award progress bonus only if later testing shows bombs are too scarce; do not add this bonus by default.
- Settler walking direction/interval choices draw from `gameplay_rng` (§6.3).

### 4.6 Planet loss and restoration

This transition is state-machine-explicit — do not leave any step to be improvised at build time.

**Trigger:** the moment the last Settler transitions to `LOST` or `MUTATED`, the run enters `PLANET_COLLAPSE`.

**`PLANET_COLLAPSE` (transitional state, not a wave):**
1. Cancel all unspawned encounters from the currently active normal wave — nothing new spawns from that wave's budget.
2. Convert every currently active Snatcher into a Ravager (whether or not it was carrying a Settler — there are none left to carry).
3. No new Snatchers spawn from this point until the planet is restored.
4. Allow all currently active enemies (Ravagers, Mine Layers, Brood Pods, Splinters, Interceptors) to be cleared normally by the player — this is not an automatic wipe.
5. The interrupted normal wave does **not** count as an extinction wave and awards **no** wave-clear bonus; its partial kills already scored normally as they happened.
6. Once the battlefield is clear (no active hostiles remain), play the planet-collapse visual/audio transition, replace terrain presentation with the scorched variant, and begin **Extinction Wave 1**.

**Extinction waves (5 total, no Settlers present):**
- Recipe: convert that wave-index's normal Snatcher budget entirely into Ravagers-at-start (there's nothing to abduct, so Snatchers have no role here). Retain Mine Layers and Brood Pods at roughly half their equivalent normal-wave concurrent count — they still create route pressure and split threats without a rescue objective to protect. The Interceptor anti-stall timer does not reset between extinction waves; a lingering player is already under Ravager pressure.
- Each extinction wave clears under the same wave-lifecycle rules as a normal wave (§6.1) once its encounter budget is exhausted and all score-bearing enemies are destroyed.
- Extinction waves are numbered independently (Extinction Wave 1–5) and do not consume or affect the normal wave counter.

**Restoration:** after Extinction Wave 5 clears, restore the planet — regenerate the normal terrain presentation, spawn 10 fresh Settlers, and resume normal numbered-wave progression at the next wave number after the one that was interrupted by collapse. This cycle may repeat indefinitely.

**Balance note (carry into Milestone 6):** a 10-Settler population against a 1–2 concurrent-abduction cap may make reaching `PLANET_COLLAPSE` rare in ordinary play, which would leave this entire subsystem — a full Milestone 4 content chunk — effectively unseen. The M6 balance pass must explicitly verify the extinction/restoration cycle is actually reachable under normal (non-optimal) Pilot play, and raise the late-wave abduction cap or lower the Settler population if it isn't.

---

## 5. Enemy Roster

Use original shipped names and original silhouettes. Internal class names may include the classic role in comments, but the UI must use these names.

| Enemy | Classic role | Behavior | Starting speed | Attack cadence | HP | Score |
|---|---|---|---:|---:|---:|---:|
| **Snatcher** | Abductor | Reserves the nearest available Settler, descends, grabs it, and ascends; converts into a Ravager on escape | 80↓ / 60↑ | aimed shot every 2.0 s | 1 | 150 |
| **Ravager** | Transformed elite | Fast pursuit via wrapped shortest-path plus sinusoidal jitter | ~200 | aimed shot every 1.5 s | 1 | 250 |
| **Mine Layer** | Area denial | Horizontal patrol at varied altitude; leaves drifting timed/proximity mines | ~120 | mine every 1.5–2.5 s | 1 | 200 |
| **Brood Pod** | Splitter | Slow drifting target with no direct attack; releases 4–6 Splinters when destroyed | ~50 | none | 1 | 500 |
| **Splinter** | Swarm spawn | Small, fast, erratic attacker released by a Brood Pod | ~250 | occasional shot every 2–4 s | 1 | 75 |
| **Interceptor** | Anti-stall | Appears after the wave target time and relentlessly pressures the player via collision homing | ~350 | collision only | 1 | 300 |

### Enemy design rules

- Normal enemies die in one accurate hit.
- Difficulty comes from movement, combinations, positioning, and timing—not health inflation.
- No enemy may spawn inside the immediate camera safety radius.
- Off-screen threats require a minimum warning window.
- Early waves cap active abductions at one; later waves may permit two.
- Interceptors do not count toward the finite encounter budget and stop spawning as soon as the wave enters `CLEAR_PENDING`.
- Brood Pod destruction must not create Splinters after the wave has already entered transition.
- Every enemy uses shortest wrapped distance for targeting and direction choice.
- Enemy firing-interval and movement-jitter timing draws from `gameplay_rng` (§6.3), never `encounter_rng`.

---

## 6. Waves and Difficulty

### 6.1 Wave lifecycle

`PRE_WAVE → ACTIVE → CLEAR_PENDING → WAVE_COMPLETE → PRE_WAVE`

(`PLANET_COLLAPSE` and the numbered `EXTINCTION_WAVE` states, defined in §4.6, are a parallel branch entered only when the last Settler is lost — see that section for their own lifecycle and recipe.)

A normal wave clears only when:

- its authored encounter budget is exhausted;
- all required spawns have occurred;
- all score-bearing enemies are destroyed or have exited under an explicit rule;
- no unresolved Settler abduction/catch transition remains.

The transition must tolerate simultaneous player death, last-enemy death, Pulse Bomb kills, and Settler release without double-awarding bonuses or soft-locking. Game-over wins if lives = 0 at the moment of a simultaneous wave-clear/player-death.

### 6.2 Initial wave recipe

| Wave | Snatchers | Mine Layers | Brood Pods | Ravagers at start | Active abduction cap | Interceptor timer |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 4 | 0 | 0 | 0 | 1 | 45 s |
| 2 | 5 | 1 | 0 | 0 | 1 | 40 s |
| 3 | 6 | 1 | 1 | 0 | 1 | 35 s |
| 4 | 7 | 2 | 1 | 0 | 2 | 32 s |
| 5 | 8 | 2 | 2 | 0 | 2 | 30 s |

After wave 5, use data-driven encounter budgets, starting from these formulas:

```text
snatcher_count    = 5 + floor(wave / 2)
mine_layer_count  = 1 + floor(wave / 3)
brood_pod_count   = 1 + floor((wave - 1) / 3)
speed_multiplier  = min(1.8, 1.0 + (wave - 5) * 0.04)
interceptor_timer_sec = max(18, 30 - (wave - 5) * 1.5)
```

These are starting values, not sacred arcade constants. Keep independent caps for active enemies, hostile projectiles, mines, and simultaneous abductions. Naturally created Ravagers persist until destroyed; do not add starting Ravagers to normal planet waves unless playtesting demonstrates a need.

### 6.3 Determinism and randomness

Pilot and Ace use a run seed. Given the same:

- game version;
- difficulty;
- run seed;
- wave number;
- surviving population;
- planet state;

the encounter schedule should be reproducible. Physics need not be bit-identical across platforms, but spawn composition and timing should be.

**Use three separate, explicitly-scoped random number generators — never one shared RNG:**

- `encounter_rng` — owned exclusively by `WaveDirector`. Deterministically seeded, ideally by deriving each wave's encounter seed from the run seed and wave number (e.g. `hash(run_seed, wave_number)`). Governs only what spawns, when, and in what composition.
- `gameplay_rng` — hyperspace destination/failure rolls, enemy AI timing/firing intervals, Settler walking choices. Not required to be reproducible run-to-run.
- `cosmetic_rng` — particle variation, SFX pitch variation, and other presentation-only randomness. Never touches gameplay state.

This separation exists so that adding a random particle variant or an SFX pitch wobble can never perturb the authored encounter schedule that Pilot/Ace determinism and the balance pass depend on. If a change to cosmetic or moment-to-moment gameplay code ever appears to shift wave composition, that's a sign a system reached into the wrong generator — fix the boundary, don't loosen the determinism requirement.

Display the run seed in the final score report.

### 6.4 Difficulty presets

| Setting | Lives | Bombs | Enemy speed | Hyperspace failure | Catch forgiveness | High-score table |
|---|---:|---:|---:|---:|---|---|
| Cadet | 5 | 5 | 0.80× | 0% | Large | Assisted |
| Pilot | 3 | 3 | 1.00× | 10% | Standard | Canonical |
| Ace | 3 | 2 | 1.20× | 15% | Tight | Ace |

Gameplay-changing assists permanently mark a run as assisted. Cosmetic accessibility settings do not.

---

## 7. Scoring

All values are provisional balance resources.

| Event | Starting score |
|---|---:|
| Destroy Snatcher | 150 |
| Destroy Ravager | 250 |
| Destroy Mine Layer | 200 |
| Destroy Brood Pod | 500 |
| Destroy Splinter | 75 |
| Destroy Interceptor | 300 |
| Catch falling Settler | 250 |
| Return Settler safely | 750 |
| Wave clear | 100 × wave |
| Each surviving Settler | 100 × wave |
| Perfect-population wave | 1,000 + 100 × wave |

Rules:

- Score is awarded through typed events, never directly from actor scripts.
- A single entity may award score only once.
- Pulse Bomb kills award normal enemy points.
- Splinters released by a Brood Pod award their own points.
- No score multiplier in v1. It is a post-release possibility, not an MVP requirement.
- Store top ten scores separately by difficulty and assist classification.
- Final report shows score, high score, wave, Settlers saved/lost, enemies by type, accuracy, bombs used, play time, seed, and game version.

---

## 8. Controls and Accessibility

### Default keyboard

| Action | Keys |
|---|---|
| Move | WASD or arrows |
| Fire | Space or J |
| Pulse Bomb | E or K |
| Hyperspace | Q or L |
| Pause | Escape or P |

### Default gamepad

| Action | Binding |
|---|---|
| Move | Left stick or D-pad |
| Fire | South face button or right trigger |
| Pulse Bomb | West face button or left trigger |
| Hyperspace | North face button or right shoulder |
| Pause | Start/Menu |

Requirements for v1 (kept intentionally lean — see §2 for what's deferred to `docs/BACKLOG.md`):

- Bindings above are defined through Godot's `InputMap` from day one, so keyboard and gamepad both work at no extra cost. There is no remap UI in v1, and — since there is nothing to remap to — no persisted custom-binding data or binding-conflict handling either (see §10.8).
- Gamepad dead-zone configuration.
- Gamepad disconnect pauses the game safely.
- Independent master, music, and effects volume (the music bus is present even though music itself is optional for v1 — see §9).
- Screen shake: Off/Low/Full.
- Flash intensity: Reduced/Full.
- Reduced particles toggle.
- Every important state differs by icon/shape or motion, not color alone, as a base art-direction rule (not a separate colorblind-mode system to build and test).
- All essential audio cues also have visual equivalents.
- Menus are fully usable without a mouse using default bindings.

---

## 9. Visual and Audio Direction

### Visual style

- Original luminous geometric vector style.
- Deep navy/black space background.
- Distinct silhouettes are more important than texture detail.
- Three restrained parallax layers built with `Parallax2D`, covering non-colliding background presentation only (stars, auroral haze, distant ridges) — gameplay terrain is a separate, singular simulation object (§3, §10.3).
- Terrain is a continuous geometric ridge with three landmark regions.
- Scanner and HUD should be clean and functional, not a copy of another game's exact arrangement.
- Optional CRT treatment is post-v1 (`docs/BACKLOG.md`) unless it is trivial and disabled by default.

**Color palette** (hex values — starting point, not final; every color also carries a shape/motion distinction per §8):

| Element | Color | Notes |
|---|---|---|
| Player ship | `#00FF88` | bright cyan-green |
| Arc Lance | `#FFFFFF` → `#88FFCC` | white core, cyan glow falloff |
| Snatcher | `#FF6600` | orange |
| Ravager | `#FF0044` | red — reserved for direct-threat enemies |
| Mine Layer | `#666666` | grey, reads as "hazard" not "chaser" |
| Brood Pod / Splinter | `#00FF00` | shared green family — a split reads as "the same thing, smaller" |
| Interceptor | `#00CCFF` | cyan — see readability note below |
| Settler | `#FFFFCC` | warm white, the most human-readable color on screen |
| Terrain | `#885522` | brown-earth ridge |
| HUD text | `#FFCC00` | gold |
| Danger/critical (reserved) | `#FF0000` | limited use — screen-edge warnings, low-population state only |

> **Readability watch item:** the Interceptor's cyan (`#00CCFF`) sits close in hue to the player ship's cyan-green (`#00FF88`), and the Interceptor is the fastest pure-collision-homing enemy in the roster. The shape/motion-differentiation rule (§8) should cover this, but hue is still doing real work in fast peripheral-vision recognition. Watch for this specifically in the first playtest; if it's confusing in practice, shifting the Interceptor to the magenta family is a one-line palette change, not a redesign.

### Audio

- Original synthesized SFX (via jsfxr) for fire, impact, explosion, abduction lock, falling Settler, catch, delivery, mutation, bomb, hyperspace, wave start, extra life, and UI navigation. This is the only audio v1 requires.
- **Music is optional for v1.** If included, it's a single simple original gameplay loop plus short title and game-over variations (or a single verified CC0 chiptune loop, per §3/§18) — not a multi-track or adaptive score. If no music ships in v1, the game must still be complete and satisfying with SFX alone.
- If music is present: rescue and danger cues take mix priority over weapons; weapons take priority over music. If no music is present, these priority rules simply have nothing to compete with.
- Avoid recognizable downloaded samples.
- Separate buses: Master, Music, SFX, UI (the Music bus exists regardless of whether v1 ships with a track).

---

## 10. Technical Architecture

### 10.1 Project layout

```text
res://
  autoload/
    app_state.gd
    save_service.gd
    audio_director.gd
  scenes/
    boot/
      boot.tscn
    menus/
      title_screen.tscn
      how_to_play.tscn
      options_menu.tscn
      high_scores.tscn
      credits.tscn
      game_over.tscn
    game/
      game_session.tscn
      world.tscn
      terrain.tscn
      hud.tscn
      scanner.tscn
    actors/
      player.tscn
      settler.tscn
      enemies/
        snatcher.tscn
        ravager.tscn
        mine_layer.tscn
        brood_pod.tscn
        splinter.tscn
        interceptor.tscn
      projectiles/
        player_shot.tscn
        enemy_shot.tscn
        mine.tscn
    effects/
  scripts/
    core/
      ring_world.gd
      run_controller.gd
      wave_director.gd
      score_service.gd
      threat_registry.gd
      settler_coordinator.gd
      balance_loader.gd
      rng_streams.gd
    actors/
    ui/
  resources/
    balance/
      player_balance.tres
      scoring_balance.tres
      difficulty/
      enemies/
    encounters/
      waves_01_05.tres
      extinction_waves.tres
      endless_curve.tres
    strings/
  assets/
    art/
    fonts/
    audio/
  shaders/
  tests/
    test_runner.gd
    unit/
    integration/
  licenses/
  docs/
    DECISIONS.md
    BACKLOG.md
```

### 10.2 Autoload responsibilities

**AppState**
- boot/menu/run transitions;
- current difficulty;
- pause and retry flow;
- no direct actor references.

**SaveService**
- versioned settings (volume levels, difficulty preference);
- top-ten score tables;
- atomic writes where supported;
- corruption recovery;
- non-blocking "saving unavailable" state for Web.

v1 has no remap UI and no interactive tutorial to track completion of (only a how-to-play screen reachable anytime from the menu), so SaveService does not persist input bindings or a "tutorial seen" flag in v1 — there is no reachable state for either to represent. Both become real save-schema additions in v1.1 alongside the remap UI (§2, §8).

**AudioDirector**
- buses and volume;
- music state transitions (a no-op if v1 ships without music);
- pooled one-shot players if profiling requires them;
- no gameplay authority.

Run-specific state belongs to `RunController` inside `game_session.tscn`, not a permanent global singleton.

### 10.3 Ring-world service

Centralize all wrapped math.

Conceptual operations:

```gdscript
normalize_x(x) -> float
wrapped_delta_x(from_x, to_x) -> float
wrapped_distance_x(from_x, to_x) -> float
camera_relative_x(world_x, camera_x) -> float
```

Required behavior:

- `normalize_x` always returns `[0, world_width)`, including negative and multi-wrap inputs.
- `wrapped_delta_x` returns the shortest signed displacement in `[-world_width/2, world_width/2)`. Define and test the half-world tie case explicitly.
- Targeting, camera-relative rendering, scanner mapping, spawn selection, and abduction seeking all call this service.
- Do not implement wrapping with left/right trigger zones or `WORLD_WIDTH - position.x`.
- Keep one simulation object per entity.
- Near a seam, render one or more non-interactive visual proxies at `x ± world_width`.
- Proxies must contain no collision, script authority, signals, health, or score behavior.
- Gameplay terrain (height profile + collision + `get_surface_y()`) is part of this simulation layer, not the `Parallax2D` presentation layer (§3, §9) — it repeats seamlessly through the same seam-aware proxy technique as every other entity, not through parallax tiling.

### 10.4 Actor composition

**Player**
- `CharacterBody2D`
- movement component/state;
- weapon component;
- hurtbox;
- carried-Settler anchor;
- invulnerability state;
- visual proxy renderer.

**Enemies and projectiles**
- `Area2D` with fixed-step manual motion unless a specific enemy requires `CharacterBody2D`.
- Small explicit state machines.
- Shared damageable/score-source contracts.
- Prefer composition for movement and weapon behavior over one giant enemy base script.

**Settler**
- `CharacterBody2D` or an equivalent kinematic implementation.
- Explicit enum state machine.
- Ownership changes only through `SettlerCoordinator`.
- State transitions emit typed events.

### 10.5 Collision layers

| Layer | Purpose |
|---:|---|
| 1 | Player body |
| 2 | Player weapon |
| 3 | Enemy body |
| 4 | Enemy weapon/mine |
| 5 | Settler body/catch area |
| 6 | Terrain |
| 7 | Non-damaging triggers |

Use masks so only intended pairs interact. Visual seam proxies are on no physics layer.

### 10.6 Event flow

- Actors emit typed domain events.
- `ScoreService` applies score and threshold rewards.
- `RunController` owns lives, bombs, wave, population, and run-end decisions.
- `SettlerCoordinator` owns Settler reservations and carriers.
- `ThreatRegistry` exposes normalized scanner contacts; the scanner never searches the scene tree every frame.
- `WaveDirector` owns encounter schedule (including the `PLANET_COLLAPSE`/extinction-wave branch, §4.6) and wave-clear resolution.
- `rng_streams.gd` exposes the three scoped generators from §6.3; nothing pulls from Godot's default global RNG for gameplay- or encounter-affecting rolls.
- Avoid `get_tree().get_nodes_in_group()` in hot per-frame paths.

### 10.7 Object pooling

Do not build a universal pool at project start.

- Instantiate normally during early milestones.
- Profile representative waves.
- Pool only high-frequency projectiles and short-lived effects if allocation or garbage-collection spikes are measurable.
- Enemies should remain normal scenes unless profiling proves otherwise.

### 10.8 Save behavior

Persist:

- schema version;
- settings (volume, difficulty preference);
- local high scores;
- optional aggregate local statistics.

Do not persist input bindings or a tutorial/how-to-play-seen flag in v1 (see §10.2) — add both when the v1.1 remap UI ships.

Use `user://`. Web persistence may be unavailable when browser storage is blocked; gameplay must continue and the UI must state that scores will not persist.

---

## 11. Scanner and HUD

### Scanner

- Fixed HUD `Control`, drawn procedurally.
- Maps normalized world X to scanner X.
- Maps gameplay Y coarsely to scanner Y.
- Shows:
  - player;
  - each enemy by role;
  - Settlers;
  - abducted/falling Settlers;
  - current viewport bracket;
  - seam-aware threat direction.
- Update contact data through `ThreatRegistry`.
- Rendering at 30 Hz is acceptable if it reduces overhead; simulation data remains current.

### HUD

Display:

- score and high score;
- wave (or `PLANET COLLAPSE` / `EXTINCTION WAVE n` during that branch, §4.6);
- reserve lives;
- bombs;
- surviving Settlers;
- difficulty;
- temporary warning banners.

Keep the scanner and HUD inside a 5% safe margin.

---

## 12. Testing

Use a dependency-free headless test runner. Verify the exact CLI invocation against the pinned Godot 4.7 build's `godot --help` output before relying on it — for example, `--quit-after <int>` ("quit after the given number of iterations") is a documented option, but confirm it against the actual installed build rather than assuming any particular flag set survives every point release. Record the working command in `README.md`. A typical shape is:

```bash
godot --headless --path project --script res://tests/test_runner.gd
```

...plus a boot smoke test that loads and quits cleanly. Use a dependency-free runner (simple assert functions + process exit code) rather than pulling in an external test framework for v1.

### Required automated tests

#### Ring math

- negative X;
- zero;
- exact seam;
- just before and after seam;
- multiple world widths;
- half-world tie behavior;
- shortest-path targeting across seam;
- camera-relative positions.

#### Scanner

- entity at X=0 and X≈world width;
- viewport bracket crossing seam;
- correct icon class and state;
- high/low Y mapping.

#### Settler state machine

- reservation conflict;
- pickup;
- carrier destruction;
- successful escape/mutation;
- falling catch;
- low and high terrain impact;
- player death while carrying;
- hyperspace success/failure while carrying;
- delivery;
- all-Settlers-lost transition into `PLANET_COLLAPSE`.

#### Waves and planet collapse

- deterministic schedule from seed (`encounter_rng` only — verify that varying `gameplay_rng`/`cosmetic_rng` seeds does not change the encounter schedule);
- abduction cap;
- spawn safety radius;
- Interceptor timer;
- Pulse Bomb killing the last enemies;
- player death simultaneous with wave clear;
- Brood Pod split at clear boundary;
- `PLANET_COLLAPSE` cancels unspawned encounters and blocks new Snatcher spawns;
- interrupted wave awards no wave-clear bonus and does not count as an extinction wave;
- extinction-wave count (exactly 5) and restoration to a normal wave with 10 Settlers.

#### Scoring and rewards

- single award per entity;
- extra-life thresholds;
- bomb thresholds and cap;
- wave and Settler bonuses;
- separate difficulty/assist tables.

#### Saves

- first run;
- normal load;
- corrupted JSON/config;
- old schema migration;
- unavailable Web persistence.

### Manual acceptance checks

- Seam crossing is visually continuous.
- No seam double-collision, duplicate score, duplicate audio, or duplicate shot.
- Threats just across the seam use the short route.
- New players understand movement and firing within 30 seconds.
- The first abduction teaches catch-and-return without text overload.
- No unavoidable damage immediately after spawn/respawn.
- Keyboard-only and gamepad-only complete flows work.
- Focus loss and controller disconnect pause safely.
- 4:3 through 32:9 show the same gameplay area.
- Reduced flash/shake/particles modes remain readable.
- A 30-minute soak run does not leak actors, audio players, or effects.
- The Interceptor is visually distinguishable from the player ship at speed in peripheral vision (§9 readability watch item).

---

## 13. Milestones

### Milestone 0 — Repository and foundation

Tasks:

- Create repository and Godot 4.7 Compatibility project.
- Add README with pinned version/export templates.
- Add project license decision, asset manifest, third-party notice template, `docs/DECISIONS.md`, and `docs/BACKLOG.md`.
- Create logical 1280×720 display settings.
- Define InputMap actions.
- Add headless test runner; verify the working CLI invocation (including whether `--quit-after` or an equivalent is available) against the installed Godot build and record it in README.
- Create empty boot/title/game-session scenes.

Exit criteria:

- Project opens and boots cleanly.
- Headless boot and empty tests pass.
- No unlicensed external asset is present.

### Milestone 1 — Flight laboratory

Tasks:

- Implement `RingWorld`.
- Add exhaustive ring-math tests.
- Implement `rng_streams.gd` with the three scoped generators from §6.3 before any other system needs randomness.
- Build polygon player, inertia, reversal, vertical bounds, camera look-ahead, and seam rendering.
- Add primary fire, target dummies, collisions, and basic terrain.
- Add keyboard and gamepad input foundation.
- Add debug overlays for logical X, normalized X, wrapped delta, velocity, and FPS.
- **Validate the §4.2 movement/weapon values in viewport-relative terms** (screen-crossing time, world-lap time, Arc Lance closing speed vs. player speed, reversal time, look-ahead distance) before locking them as the Phase 1 baseline; adjust pixel values as needed.

Exit criteria:

- Flying, reversing, shooting, and crossing the seam remain enjoyable and stable for five minutes.
- No duplicate seam collision or visible pop.
- All ring tests pass.
- Movement/weapon values have been validated at 1280×720, not just carried over from an earlier draft.

### Milestone 2 — Rescue vertical slice

Tasks:

- Build continuous terrain lookup.
- Add one Settler and Settler state machine.
- Add Snatcher behavior: seek, reserve, descend, carry, ascend, mutate.
- Add falling, catching, carrying, and returning.
- Add scanner and directional warnings.
- Add temporary score/population HUD.
- Build one finite wave and game-over/retry path.

Exit criteria:

- Player can detect an abduction across the seam, intercept, catch, return, fail, lose the Settler, and retry.
- Reservation conflicts and all Settler transitions pass tests.

### Milestone 3 — Complete arcade loop

Tasks:

- Add lives, death, respawn safety, invulnerability.
- Add Pulse Bomb.
- Add Hyperspace.
- Add waves 1–5, rewards, high-score foundation, and difficulty presets.
- Add wave transitions and simultaneous-event resolution.

Exit criteria:

- Boot-to-game-over-to-instant-retry works.
- No wave-clear soft locks.
- Pilot rules produce a complete five-wave run.

### Milestone 4 — Full enemy roster and planet cycle

Tasks:

- Add Ravager, Mine Layer, Brood Pod, Splinter, and Interceptor.
- Add finite encounter budgets and deterministic seed (`encounter_rng`).
- Implement `PLANET_COLLAPSE` and the five-extinction-wave recipe exactly as specified in §4.6 — cancellation of unspawned encounters, Snatcher→Ravager conversion, no wave-clear bonus for the interrupted wave, the extinction recipe, and restoration.
- Add performance caps and only profile-driven pooling.

Exit criteria:

- Every enemy has distinct readable behavior.
- Planet loss/restoration cycle completes without state errors, including the specific `PLANET_COLLAPSE` transition rules from §4.6.
- Worst authored wave remains readable and meets frame target on development hardware.

### Milestone 5 — Presentation, saves, and accessibility

Tasks:

- Final title, how-to-play, options, pause, credits/licenses, high scores, and game-over report.
- Versioned saves and graceful storage failure (settings and scores only — see §10.8).
- Volume, shake, flash, and particle options; gamepad dead-zone configuration.
- Original art pass and original synthesized SFX (required). Optionally, one original or verified CC0 music loop (not required for v1 — see §9).
- Externalize player-facing strings.

Exit criteria:

- Full flow is usable by keyboard or gamepad using default bindings.
- No temporary or unknown-license asset remains.
- Save corruption and unavailable-storage tests pass.

### Milestone 6 — Balance and release candidate

Tasks:

- Structured playtests for control, rescue clarity, fairness, and retry behavior.
- Tune world width, speeds, catch radius, wave recipes, score thresholds, and difficulty.
- **Explicitly verify the extinction/restoration cycle (§4.6) is reachable under normal, non-optimal Pilot play** — if a competent-but-not-perfect player essentially never triggers `PLANET_COLLAPSE`, raise the late-wave concurrent-abduction cap or lower the Settler population until it's a real, occasional threat rather than unreachable content.
- Confirm the Interceptor/player color-adjacency readability watch item (§9) in actual playtest and adjust the palette if it's a real problem.
- Profile desktop and Web.
- Export Web, Windows, macOS, and Linux.
- Run platform acceptance and 30-minute soak tests.
- Audit licenses, originality, credits, and export contents.
- Produce checksums and release notes.

Exit criteria:

- Typical Pilot run is roughly 10–20 minutes for competent new players.
- Planet loss/restoration is a reachable, occasional event in ordinary play, not a theoretical-only system.
- 60 FPS target is met on representative integrated desktop graphics and a mid-range desktop browser.
- No known critical/high-severity defects, save-loss bugs, seam duplication, or unavoidable spawn hits.
- Release archive contains exact engine version, notices, checksums, known platform caveats, and test report.

---

## 14. Performance Targets

- 60 FPS.
- Representative maximum:
  - 1 player;
  - 10 Settlers;
  - 40 enemies;
  - 120 hostile projectiles/mines;
  - 40 player shots;
  - 200 short-lived effects.
- Initial compressed Web download target: under 30 MB.
- No per-frame full-scene searches.
- No unbounded particle systems.
- No native extensions.
- Profile CPU, GPU, memory, and Web size at Milestones 4–6.

These are budgets to validate, not assumptions that every cap must be reached.

---

## 15. Definition of Done

FYTR9 v1.0 is complete when:

- The full boot-to-retry loop works on supported Web and desktop targets.
- Movement, seam behavior, scanner, rescue, all six enemy roles, bombs, hyperspace, waves, planet loss/restoration (including the explicit `PLANET_COLLAPSE`/extinction-wave transition), scoring, lives, saves, and difficulty modes meet their acceptance tests.
- Keyboard and gamepad are fully playable with default bindings.
- Gameplay remains understandable without audio and without color as the only signal.
- All aspect ratios preserve equal gameplay visibility.
- Pilot is fair, readable, and replayable; Cadet and Ace are clearly distinct.
- No critical/high defects, soft locks, duplicate seam collisions, duplicate score awards, or save-loss bugs remain.
- Every shipped file is original or has verified compatible licensing and provenance.
- The game has an original visual, audio, terminology, UI, and tuning identity.
- Reproducible release exports, checksums, engine/export-template versions, notices, and acceptance results are archived.

---

## 16. Explicitly rejected implementation choices

These are anti-patterns other drafts of this plan drifted toward, or that are easy mistakes given the design above. Do not do these:

- Edge-trigger teleport zones or `WORLD_WIDTH - position.x` for wrapping — use `RingWorld`'s modulo math exclusively (§10.3).
- Non-wrapping enemies or projectiles — everything in the simulation wraps.
- The deprecated `ParallaxBackground` / `ParallaxLayer` nodes — use `Parallax2D`.
- Letting `Parallax2D` own gameplay terrain — terrain is a singular simulation object with real collision and `get_surface_y()` queries, not a repeating decorative layer (§3, §9, §10.3).
- Physics-enabled seam duplicates — visual proxies carry no collision, signals, health, or score behavior.
- Run-specific state (score, lives, wave, Settler roster) owned by a permanent global singleton — it belongs to `RunController` inside the session scene, and dies with the run.
- An artificially low, punishing player-shot cap "for arcade authenticity" — cap through lifetime/off-screen despawn instead, tune from playtesting.
- Refilling all Pulse Bombs on every death — they are a run-level resource (§4.3).
- Actor scripts directly awarding score or independently claiming Settlers — both go through `ScoreService` and `SettlerCoordinator` respectively.
- Premature universal object pooling before profiling shows an actual allocation problem (§10.7).
- Sharing one RNG instance across encounter scheduling, gameplay AI/hyperspace, and cosmetic effects — keep the three separate seeded generators from §6.3. If a cosmetic or AI-timing change ever appears to shift wave composition, that's a boundary violation, not something to shrug off.
- Treating the wave interrupted by `PLANET_COLLAPSE` as an extinction wave, awarding it a wave-clear bonus, or letting new Snatchers spawn once Settlers are extinct — see the explicit transition in §4.6.
- Persisting or testing input-binding data or a tutorial-completion flag in v1, when no remap UI or interactive tutorial exists to produce that state (§10.2, §10.8).
- Building a multi-track or adaptive music system for v1 — music is optional and, if present, is one simple loop plus two short variations at most (§9).

---

## 17. Provenance and deliberate decisions

This document's lineage: four independent original plans (Claude, Codex, DeepSeek, GLM) → two independent first-generation unifications → a second-generation merge ("final") → two independent second-generation revisions (a ChatGPT v2 and a Web Claude v2) → a third-generation merge (v3) → **independent reviews of v3 by both ChatGPT and Web Claude** → this document (v4), which resolves every substantive finding from both reviews.

### From the ChatGPT review of v3 (adopted)

- **The `PLANET_COLLAPSE` transition was under-specified.** v3 said losing all Settlers "begins five extinction waves" without saying what happens to the wave in progress, whether new Snatchers could still spawn, or whether the interrupted wave scores a clear bonus. §4.6 now fully specifies the transition and an explicit extinction-wave recipe.
- **RNG streams needed separation.** A single shared RNG would let a cosmetic particle-effect change silently perturb the "deterministic" encounter schedule. §6.3 now defines three explicitly scoped generators (`encounter_rng`, `gameplay_rng`, `cosmetic_rng`).
- **The 1280×720 tuning inheritance needed flagging.** The movement/weapon pixel values were carried over unexamined from a 640×360-canvas draft. §4.2 and Milestone 1 now explicitly mark them as unvalidated placeholders and require viewport-relative validation before they're locked.
- **The Parallax2D/terrain wording was ambiguous** and could be read as implying Parallax2D should own gameplay terrain. §3, §9, and §10.3 now explicitly separate "Parallax2D owns non-colliding background presentation" from "terrain is a singular simulation object."
- **The lives/Cadet contradiction** ("start with 3 ships" vs. Cadet's 5) is fixed in §4.4, along with clarifying the 5-ship cap includes the active ship.
- **The "Lander/Baiter are the two distinctive terms" framing read as an unnecessary legal classification.** §1 now states the full-originality decision without characterizing which of Defender's own words would or wouldn't hold up as distinctive.

### From the Web Claude review of v3 (adopted)

- **The music-scope contradiction** (§3 implying original composition, §9 requiring a track, Milestone 5 tasking "original... music," while §18/backlog said music was optional/deferred) is fully reconciled: music is optional everywhere it's mentioned, consistently, and Milestone 5 now reflects that.
- **The `--quit-after` factual error.** v3's provenance note asserted this flag lacked confirmed support; that assertion was wrong — it's a documented Godot CLI option. §3, §12, and Milestone 0 are corrected to state the general verify-before-relying-on-any-flag practice without casting unwarranted doubt on a specific real flag.
- **Vestigial save/test scope.** SaveService and the test suite referenced binding persistence, binding-conflict tests, and a tutorial-completion flag that v1 has no way to produce (no remap UI, no interactive tutorial). §8, §10.2, §10.8, and §12 now explicitly exclude these from v1 and note they arrive with the v1.1 remap UI.
- **The extinction-cycle reachability concern.** 10 Settlers against a 1–2 concurrent-abduction cap risks making `PLANET_COLLAPSE` unreachable in ordinary play, leaving a full Milestone 4 content chunk effectively unseen. Not a doc rewrite by itself, but §4.6 and Milestone 6 now carry an explicit balance-pass requirement to verify and correct this.
- **The Interceptor/player palette-adjacency nit.** Both are fast-moving and share a cyan-ish hue family. §9 and Milestone 6 now carry this as an explicit playtest watch item with a stated one-line fix if needed.

### Kept unchanged, per both reviewers' explicit agreement

- The fully original enemy roster, the Pulse-Bomb-as-run-level-resource decision, the determinism section as scoped (spawn composition/timing only, physics exempt), and the overall architecture, milestone structure, and anti-pattern list from v3. Both independent reviews characterized v3 as implementation-ready modulo the fixes above — neither asked for another structural pass, and this document doesn't take one.

The source of truth remains this document. Earlier plans and revisions are references, not competing specifications.

---

## 18. Post-v1 Backlog

Record here — and in `docs/BACKLOG.md` once the repository exists — rather than building any of these during v1:

- score multiplier/combo mode;
- boss encounters;
- full keyboard/gamepad rebinding UI, with persisted custom bindings and binding-conflict handling;
- a tracked tutorial-completion flag (once there's an interactive tutorial to track, beyond the static how-to-play screen);
- UI scaling and dedicated colorblind palette presets;
- alternate planets/palettes;
- two-player alternating mode;
- co-op;
- online leaderboard;
- CRT shader;
- mobile touch controls;
- an original composed soundtrack beyond the single optional loop described in §9.

None of these should influence the v1 architecture beyond avoiding obvious dead ends.

---

## 19. Licenses (CREDITS.md contents)

| Resource | License | Source |
|---|---|---|
| Godot Engine 4.7 | MIT | godotengine.org |
| Press Start 2P (or OFL alternative) | SIL OFL 1.1 | fonts.google.com |
| jsfxr-generated SFX | The Unlicense (public domain) | sfxr.me |
| Any supplementary CC0 art/audio | CC0 (verify per individual asset) | kenney.nl / opengameart.org |
| All original code, art, and audio | project license (recommend MIT for code, CC0/CC BY 4.0 for original art/audio) | original |
