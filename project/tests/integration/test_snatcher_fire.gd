## Snatcher aimed fire (§5: aimed shot every 2.0 s, arrived with M3 player
## death) and the anti-idle consequence: an idle player now loses the run to
## enemy pressure instead of watching waves self-resolve into WAVE COMPLETE
## (2026-07-11 playtest note; see docs/DECISIONS.md).
extends "res://tests/test_case.gd"

const SESSION_SCENE := preload("res://scenes/game/game_session.tscn")

const DT := 1.0 / 60.0


func _spawn_session(seed_value: int) -> Node2D:
	var session: Node2D = SESSION_SCENE.instantiate()
	session.get_node("RunController").fixed_seed = seed_value
	session.get_node("RunController").forced_difficulty = 1  # PILOT
	scene_tree.root.add_child(session)
	return session


func _free_session(session: Node2D) -> void:
	scene_tree.root.remove_child(session)
	session.free()


func _step_until(world: Node2D, predicate: Callable, max_ticks: int) -> bool:
	for i in max_ticks:
		world._physics_process(DT)
		if predicate.call():
			return true
	return false


func test_snatcher_fires_aimed_shots_that_kill() -> void:
	var session := _spawn_session(707)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	world.spawn_snatcher(world.ring.normalize_x(world.player.sim_x + 300.0))

	var fired := _step_until(world, func(): return not world.enemy_shots.is_empty(), 240)
	assert_true(fired, "snatcher fires within fire_interval + first-shot jitter")
	var died := _step_until(world, func(): return not world.player.alive, 600)
	assert_true(died, "an aimed shot kills the stationary player")
	assert_eq(run.lives, 2, "the hit consumed a life")
	_free_session(session)


func test_respawn_invulnerability_blocks_shots_then_expires() -> void:
	var session := _spawn_session(708)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var player: CharacterBody2D = world.player

	run.report_player_death(&"test")
	var respawned := _step_until(world, func(): return player.alive, 200)
	assert_true(respawned, "respawned")
	assert_true(player.invuln_timer > 0.0, "invulnerable on respawn")

	world.spawn_enemy_shot({"sim_x": player.sim_x, "y": player.position.y,
			"velocity": Vector2.ZERO})
	for i in 30:
		world._physics_process(DT)
	assert_true(player.alive, "invulnerability blocks hostile fire (§4.2)")

	var killed := _step_until(world, func(): return not player.alive, 240)
	assert_true(killed, "the parked shot connects once invulnerability expires")
	_free_session(session)


func test_idle_run_ends_in_game_over_not_wave_complete() -> void:
	# Playtest note (2026-07-11): pre-M3, an idle player's wave self-resolved
	# into WAVE COMPLETE with bonuses. With lives and aimed fire, idling must
	# end the run instead.
	var session := _spawn_session(2026)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var results: Array = []
	run.run_ended.connect(func(result, stats): results.append([result, stats]))

	var ticks := 0
	while not run.run_over and ticks < 60 * 180:
		world._physics_process(DT)
		ticks += 1
	assert_true(run.run_over, "an idle run ends on its own within 3 minutes")
	assert_true(results[0][0] == &"game_over" or results[0][0] == &"all_settlers_lost",
			"idling ends in defeat (%s), never WAVE COMPLETE" % results[0][0])
	_free_session(session)
