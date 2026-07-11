## WaveDirector schedule determinism (§6.3): encounter RNG consumption is
## fixed at construction, so the authored schedule can never depend on live
## player state — the M3 review found the old rejection-sampling placement
## violated this. Spawn safety (§5) is a deterministic, RNG-free transform.
extends "res://tests/test_case.gd"

const RingWorldScript := preload("res://scripts/core/ring_world.gd")
const WaveDirectorScript := preload("res://scripts/core/wave_director.gd")
const WaveRecipeScript := preload("res://scripts/core/wave_recipe.gd")

const W := 3840.0
const DT := 1.0 / 60.0


func _make_director(seed_value: int) -> WaveDirector:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return WaveDirectorScript.new(WaveRecipeScript.new(), rng, RingWorldScript.new(W))


## Run a whole wave with an uncapped field and a fixed player position;
## returns [[tick, x], ...] for every spawn.
func _collect_spawns(seed_value: int, player_x: float) -> Array:
	var director := _make_director(seed_value)
	var spawns := []
	var tick := 0
	while not director.budget_exhausted() and tick < 60 * 120:
		tick += 1
		for x in director.tick(DT, 0, player_x):
			spawns.append([tick, x])
	return spawns


func test_schedule_independent_of_player_position() -> void:
	var near_origin := _collect_spawns(4242, 640.0)
	var far_side := _collect_spawns(4242, 2600.0)
	assert_eq(near_origin.size(), far_side.size(), "same spawn count either way")
	var ring: RingWorld = RingWorldScript.new(W)
	var recipe: Resource = WaveRecipeScript.new()
	for i in near_origin.size():
		assert_eq(near_origin[i][0], far_side[i][0],
				"spawn %d fires on the same tick regardless of player position (§6.3)" % i)
		# Positions match unless the safety shift (§5) moved one; a shifted
		# spawn sits exactly on its player's safety-radius edge.
		if absf(near_origin[i][1] - far_side[i][1]) > 0.001:
			var moved_near: float = ring.wrapped_distance_x(640.0, near_origin[i][1])
			var moved_far: float = ring.wrapped_distance_x(2600.0, far_side[i][1])
			assert_true(
					absf(moved_near - recipe.spawn_min_player_distance) < 0.01
					or absf(moved_far - recipe.spawn_min_player_distance) < 0.01,
					"spawn %d differs only by the deterministic safety shift" % i)


func test_authored_draws_identical_for_same_seed() -> void:
	var first := _make_director(777)
	var second := _make_director(777)
	assert_eq(first._schedule, second._schedule,
			"pre-rolled schedule is a pure function of the encounter seed (§6.3)")
	var other := _make_director(778)
	assert_true(first._schedule != other._schedule,
			"a different seed pre-rolls a different schedule")


func test_spawn_safety_shift_is_exact_and_rng_free() -> void:
	var director := _make_director(9)
	var recipe: Resource = director.recipe
	var ring: RingWorld = RingWorldScript.new(W)
	assert_almost_eq(director._apply_spawn_safety(1010.0, 1000.0),
			ring.normalize_x(1000.0 + recipe.spawn_min_player_distance), 0.001,
			"unsafe spawn ahead of the player shifts to the +side radius edge")
	assert_almost_eq(director._apply_spawn_safety(990.0, 1000.0),
			ring.normalize_x(1000.0 - recipe.spawn_min_player_distance), 0.001,
			"unsafe spawn behind the player shifts to the -side radius edge")
	assert_almost_eq(director._apply_spawn_safety(2500.0, 1000.0), 2500.0, 0.001,
			"safe authored positions pass through untouched")


func test_all_realized_spawns_respect_safety_radius() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var recipe: Resource = WaveRecipeScript.new()
	for seed_value in [1, 2, 3, 4, 5]:
		for spawn in _collect_spawns(seed_value, 640.0):
			assert_true(ring.wrapped_distance_x(640.0, spawn[1])
					>= recipe.spawn_min_player_distance - 0.001,
					"no spawn inside the player safety radius (§5)")


func test_concurrency_cap_holds_schedule_without_consuming_it() -> void:
	var director := _make_director(31)
	for i in 600:  # 10 seconds with the field reported full
		assert_eq(director.tick(DT, director.recipe.max_concurrent_snatchers, 640.0).size(), 0,
				"capped field spawns nothing")
	assert_eq(director.remaining, director.recipe.snatcher_count,
			"held spawns are deferred, not dropped")
	var spawned := 0
	for i in 60 * 120:
		spawned += director.tick(DT, 0, 640.0).size()
	assert_eq(spawned, director.recipe.snatcher_count,
			"full budget still spawns once the field frees up")
