## WaveDirector (plan §10.6) — Milestone 2 minimal version: one finite wave
## driven by a WaveRecipe. Owns the encounter_rng exclusively (§6.3): spawn
## timing and positions draw from it and nothing else. The full multi-wave
## lifecycle, §6.2 table, and PLANET_COLLAPSE branch arrive in Milestones 3-4.
class_name WaveDirector
extends RefCounted

var recipe: Resource  # WaveRecipe
var remaining: int

var _rng: RandomNumberGenerator  # encounter_rng for this wave
var _ring: RingWorld
var _spawn_timer := 0.0


func _init(p_recipe: Resource, encounter_rng: RandomNumberGenerator, ring: RingWorld) -> void:
	recipe = p_recipe
	_rng = encounter_rng
	_ring = ring
	remaining = recipe.snatcher_count
	_spawn_timer = _rng.randf_range(recipe.spawn_interval_min, recipe.spawn_interval_max)


func budget_exhausted() -> bool:
	return remaining <= 0


## Advance the spawn schedule. Returns spawn sim_x positions due this tick
## (0 or 1 in the M2 recipe). Spawns hold while the concurrent cap is full
## and never land inside the player's safety radius (§5).
func tick(delta: float, active_enemies: int, player_sim_x: float) -> Array[float]:
	var due: Array[float] = []
	if remaining <= 0 or active_enemies >= recipe.max_concurrent_snatchers:
		return due
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return due
	_spawn_timer = _rng.randf_range(recipe.spawn_interval_min, recipe.spawn_interval_max)
	remaining -= 1
	due.append(_pick_spawn_x(player_sim_x))
	return due


func _pick_spawn_x(player_sim_x: float) -> float:
	for attempt in 32:
		var x := _rng.randf_range(0.0, _ring.width)
		if _ring.wrapped_distance_x(x, player_sim_x) >= recipe.spawn_min_player_distance:
			return x
	# Ring width (3840) vs safety radius (600) makes rejection this long
	# vanishingly unlikely; place opposite the player as a safe fallback.
	return _ring.normalize_x(player_sim_x + _ring.width * 0.5)
