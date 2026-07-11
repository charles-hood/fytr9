## WaveDirector (plan §10.6): owns one wave's encounter schedule and its
## encounter_rng exclusively (§6.3). The full schedule — every spawn's delay
## and authored ring position — is pre-rolled at construction, so encounter
## RNG consumption is a fixed function of (run seed, wave number) and can
## never depend on live gameplay state. (The M3 review found the previous
## rejection-sampling spawn placement consumed a player-position-dependent
## number of draws, breaking §6.3's reproducible-schedule contract.)
##
## Two deliberately non-authored influences remain, both RNG-free:
## - the concurrency cap holds the schedule while the field is full (§6.2
##   pressure valve) — wall-clock timing defers, order and draws do not;
## - spawn safety (§5) shifts an authored position out of the player's
##   safety radius via a deterministic transform.
class_name WaveDirector
extends RefCounted

var recipe: Resource  # WaveRecipe
var remaining: int

var _rng: RandomNumberGenerator  # encounter_rng for this wave (M4 rolls more from it)
var _ring: RingWorld
var _schedule: Array[Dictionary] = []  # [{delay: float, x: float}] in spawn order
var _spawn_timer := 0.0


func _init(p_recipe: Resource, encounter_rng: RandomNumberGenerator, ring: RingWorld) -> void:
	recipe = p_recipe
	_rng = encounter_rng
	_ring = ring
	remaining = recipe.snatcher_count
	for i in recipe.snatcher_count:
		_schedule.append({
			"delay": _rng.randf_range(recipe.spawn_interval_min, recipe.spawn_interval_max),
			"x": _rng.randf_range(0.0, _ring.width),
		})
	if not _schedule.is_empty():
		_spawn_timer = _schedule[0]["delay"]


func budget_exhausted() -> bool:
	return remaining <= 0


## Advance the spawn schedule. Returns spawn sim_x positions due this tick
## (0 or 1 for the Snatcher schedule). active_snatchers must count Snatchers
## only — the cap is §6.2's max_concurrent_snatchers, not a whole-field cap.
func tick(delta: float, active_snatchers: int, player_sim_x: float) -> Array[float]:
	var due: Array[float] = []
	if remaining <= 0 or active_snatchers >= recipe.max_concurrent_snatchers:
		return due
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return due
	var index: int = recipe.snatcher_count - remaining
	remaining -= 1
	if remaining > 0:
		_spawn_timer = _schedule[recipe.snatcher_count - remaining]["delay"]
	due.append(_apply_spawn_safety(_schedule[index]["x"], player_sim_x))
	return due


## §5: no spawn inside the player's safety radius. An unsafe authored x is
## shifted to the near edge of the radius on its own side — deterministic
## given (authored x, player position), consuming no RNG (§6.3).
func _apply_spawn_safety(x: float, player_sim_x: float) -> float:
	var delta_x: float = _ring.wrapped_delta_x(player_sim_x, x)
	if absf(delta_x) >= recipe.spawn_min_player_distance:
		return x
	var side := 1.0 if delta_x >= 0.0 else -1.0
	return _ring.normalize_x(player_sim_x + side * recipe.spawn_min_player_distance)
