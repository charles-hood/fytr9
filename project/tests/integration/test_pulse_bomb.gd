## Pulse Bomb rules (§4.3): kills inside the viewport-plus-seam-margin
## window, spares Settlers and anything beyond the window, consumes stock,
## and the stock is run-level — never refilled on death (§16).
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


func _step(world: Node2D, ticks: int) -> void:
	for i in ticks:
		world._physics_process(DT)


func test_bomb_kills_viewport_window_spares_far_and_settlers() -> void:
	var session := _spawn_session(4242)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var player: CharacterBody2D = world.player

	world.spawn_snatcher(world.ring.normalize_x(player.sim_x + 200.0))
	world.spawn_snatcher(world.ring.normalize_x(player.sim_x - 300.0))
	var far_x: float = world.ring.normalize_x(player.sim_x + 1900.0)
	world.spawn_snatcher(far_x)
	world.spawn_enemy_shot({"sim_x": world.ring.normalize_x(player.sim_x + 100.0),
			"y": player.position.y + 50.0, "velocity": Vector2.ZERO})

	run.request_pulse_bomb()
	assert_eq(run.bombs, 2, "one bomb consumed from the Pilot stock of 3")
	assert_eq(world.enemies.size(), 1, "both in-window snatchers destroyed")
	assert_almost_eq(world.enemies[0].sim_x, far_x, 0.001,
			"the enemy beyond the window survives (§4.3)")
	assert_eq(world.enemy_shots.size(), 0, "hostile projectiles in the window destroyed")
	assert_eq(run.score_service.total, 300, "bomb kills award normal §7 points")
	assert_eq(run.coordinator.alive_count(), 10, "settlers unharmed (§4.3)")
	_free_session(session)


func test_bomb_requires_stock() -> void:
	var session := _spawn_session(4243)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")

	run.bombs = 0
	world.spawn_snatcher(world.ring.normalize_x(world.player.sim_x + 200.0))
	run.request_pulse_bomb()
	assert_eq(world.enemies.size(), 1, "no detonation without stock")
	assert_eq(run.bombs, 0, "stock cannot go negative")
	_free_session(session)


func test_bombs_survive_death_not_refilled() -> void:
	var session := _spawn_session(4244)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")

	run.request_pulse_bomb()
	assert_eq(run.bombs, 2, "bomb spent")
	run.report_player_death(&"test")
	_step(world, int(world.player_balance.respawn_delay / DT) + 1)
	assert_true(world.player.alive, "respawned")
	assert_eq(run.bombs, 2, "bombs are a run-level resource — no refill on death (§4.3, §16)")
	_free_session(session)
