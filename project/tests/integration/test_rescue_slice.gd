## End-to-end Milestone 2 exit-criteria drills, run through the real
## game_session.tscn with a fixed run seed: abduction -> shoot the carrier ->
## catch the falling Settler -> deliver; a full wave cleared by kills with
## exact §7 scoring; and the mutation/population path.
extends "res://tests/test_case.gd"

const SESSION_SCENE := preload("res://scenes/game/game_session.tscn")
const SettlerScript := preload("res://scripts/actors/settler.gd")

const DT := 1.0 / 60.0


func _spawn_session(seed_value: int) -> Node2D:
	var session: Node2D = SESSION_SCENE.instantiate()
	session.get_node("RunController").fixed_seed = seed_value
	scene_tree.root.add_child(session)
	return session


func _free_session(session: Node2D) -> void:
	scene_tree.root.remove_child(session)
	session.free()


func _step(world: Node2D, ticks: int) -> void:
	for i in ticks:
		world._physics_process(DT)


func _step_until(world: Node2D, predicate: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		world._physics_process(DT)
		if predicate.call():
			return true
	return false


func _find_settler(world: Node2D, state: int) -> Node2D:
	for settler in world.settlers:
		if settler.state == state:
			return settler
	return null


func test_full_rescue_path() -> void:
	var session := _spawn_session(1234)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var player: CharacterBody2D = world.player

	# 1. An abduction happens (detectable across the whole ring).
	var grabbed := _step_until(world, func():
		return _find_settler(world, SettlerScript.State.CARRIED_BY_ENEMY) != null, 3600)
	assert_true(grabbed, "a snatcher grabs a settler within a minute")
	var settler := _find_settler(world, SettlerScript.State.CARRIED_BY_ENEMY)

	# Let the carrier lift its settler well clear of the ground first, so the
	# release produces a real (catchable) fall.
	var lifted := _step_until(world, func(): return settler.sim_y < 400.0, 900)
	assert_true(lifted, "carrier ascends with the settler")

	# 2. Shoot the carrier (shot spawned just behind it, flying its way).
	var carrier: Area2D = null
	for enemy in world.enemies:
		if enemy.state == 2:  # Snatcher.State.ASCEND
			carrier = enemy
	assert_true(carrier != null, "carrier found among enemies")
	world.spawn_player_shot(world.ring.normalize_x(carrier.sim_x - 40.0), carrier.sim_y, 1)
	var dropped := _step_until(world, func():
		return settler.state == SettlerScript.State.FALLING, 30)
	assert_true(dropped, "destroying the carrier releases the settler")

	# 3. Catch by overlap: put the craft on the falling settler.
	player.position.x += world.ring.wrapped_delta_x(player.sim_x, settler.sim_x)
	player.position.y = settler.sim_y
	var caught := _step_until(world, func():
		return settler.state == SettlerScript.State.CARRIED_BY_PLAYER, 10)
	assert_true(caught, "player catches the falling settler by overlap")

	# 4. Deliver: descend into the safe drop band.
	player.position.y = world.terrain.get_surface_y(player.sim_x) - 40.0
	var delivered := _step_until(world, func():
		return settler.state == SettlerScript.State.DELIVERED, 10)
	assert_true(delivered, "safe drop band returns the settler to the surface")
	assert_eq(run.score_service.total, 150 + 250 + 750,
			"kill + catch + return scored exactly once each (§7)")
	assert_eq(run.coordinator.alive_count(), 10, "no settler lost in the round trip")

	# 5. DELIVERED recovers to SAFE.
	var recovered := _step_until(world, func():
		return settler.state == SettlerScript.State.SAFE, 200)
	assert_true(recovered, "delivered settler recovers to SAFE")
	_free_session(session)


func test_wave_cleared_by_kills_scores_exactly() -> void:
	var session := _spawn_session(99)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var results: Array = []
	run.run_ended.connect(func(result, stats): results.append([result, stats]))

	var ticks := 0
	while not run.run_over and ticks < 10000:
		world._physics_process(DT)
		ticks += 1
		for enemy in world.enemies.duplicate():
			enemy.take_hit()
	assert_true(run.run_over, "run ends once the budget is spent and field is clear")
	assert_eq(results.size(), 1, "run_ended emitted exactly once")
	assert_eq(results[0][0], &"wave_complete", "clearing every snatcher completes the wave")
	# 4 snatchers ×150 + wave clear 100 + 10 survivors ×100 + perfect 1000+100.
	assert_eq(run.score_service.total, 600 + 100 + 1000 + 1100,
			"wave scoring matches §7 exactly")
	assert_eq(results[0][1]["seed"], 99, "run seed reported in the final stats")
	_free_session(session)


func test_mutation_reduces_population() -> void:
	var session := _spawn_session(555)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")

	var mutated := _step_until(world, func():
		return _find_settler(world, SettlerScript.State.MUTATED) != null, 7200)
	assert_true(mutated, "an uncontested snatcher escapes with its settler within 2 minutes")
	assert_eq(run.coordinator.alive_count(), 9, "population drops to 9")
	assert_eq(run.score_service.total, 0, "escape awards no score")
	assert_false(run.run_over, "run continues with settlers remaining")
	_free_session(session)


func test_deterministic_wave_schedule_from_seed() -> void:
	# Same fixed seed twice: the first spawn happens on the same tick at the
	# same position (encounter_rng determinism, §6.3).
	var first: Array = _first_spawn_signature(4321)
	var second: Array = _first_spawn_signature(4321)
	assert_eq(first[0], second[0], "first spawn tick reproducible")
	assert_almost_eq(first[1], second[1], 0.0001, "first spawn position reproducible")
	var other: Array = _first_spawn_signature(8765)
	assert_true(first[0] != other[0] or absf(first[1] - other[1]) > 0.001,
			"different seed produces a different schedule")


func _first_spawn_signature(seed_value: int) -> Array:
	var session := _spawn_session(seed_value)
	var world: Node2D = session.get_node("World")
	var ticks := 0
	while world.enemies.is_empty() and ticks < 600:
		world._physics_process(DT)
		ticks += 1
	var signature := [ticks, 0.0]
	if not world.enemies.is_empty():
		signature[1] = world.enemies[0].sim_x
	_free_session(session)
	return signature
