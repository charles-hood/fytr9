## Hyperspace rules (§4.3): destinations are selected safe-first (terrain
## clearance band, hostile clearance) with the failure roll applied only
## afterwards; success grants 0.75 s invulnerability; failure destroys the
## ship at the origin, dropping any carried Settler there.
extends "res://tests/test_case.gd"

const SESSION_SCENE := preload("res://scenes/game/game_session.tscn")
const SettlerScript := preload("res://scripts/actors/settler.gd")

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


func test_successful_jumps_land_safely_with_invulnerability() -> void:
	var session := _spawn_session(9191)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var player: CharacterBody2D = world.player
	run.preset = run.preset.duplicate()
	run.preset.hyperspace_failure_chance = 0.0

	for offset in [400.0, 1200.0, 2600.0]:
		world.spawn_snatcher(world.ring.normalize_x(player.sim_x + offset))

	var y_max: float = world.terrain.min_surface_y() \
			- world.player_balance.hyperspace_terrain_clearance
	for i in 40:
		run.request_hyperspace()
		assert_true(player.alive, "0%% failure never destroys the ship")
		assert_almost_eq(player.invuln_timer,
				world.player_balance.hyperspace_invulnerability, 0.001,
				"success grants 0.75s invulnerability (§4.3)")
		assert_true(player.position.y >= world.world_balance.min_player_y
				and player.position.y <= y_max,
				"destination inside the safe vertical band, clear of terrain")
		assert_almost_eq(player.sim_x, world.ring.normalize_x(player.position.x), 0.001,
				"anchor and ring position stay consistent through the jump")
		for enemy in world.enemies:
			var dx: float = world.ring.wrapped_delta_x(player.sim_x, enemy.sim_x)
			var dy: float = enemy.sim_y - player.position.y
			assert_true(Vector2(dx, dy).length()
					>= world.player_balance.hyperspace_min_clearance - 0.001,
					"destination rejected unsafe candidates near hostiles (§4.3)")
	_free_session(session)


func test_failed_jump_destroys_ship_at_origin_dropping_settler() -> void:
	var session := _spawn_session(9192)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var player: CharacterBody2D = world.player
	run.preset = run.preset.duplicate()
	run.preset.hyperspace_failure_chance = 1.0

	var settler: Node2D = world.settlers[0]
	settler.apply_state(SettlerScript.State.CARRIED_BY_PLAYER)
	settler.sim_x = player.sim_x
	settler.sim_y = player.position.y + 26.0
	var origin_x: float = player.sim_x

	run.request_hyperspace()
	assert_false(player.alive, "failed jump destroys the active ship (§4.3)")
	assert_eq(run.lives, 2, "a life is consumed")
	assert_eq(settler.state, SettlerScript.State.FALLING,
			"carried settler begins falling on failure (§4.3)")
	assert_almost_eq(player.sim_x, origin_x, 0.001,
			"failure happens at the origin — the ship never left")
	assert_almost_eq(settler.sim_x, origin_x, 0.001, "settler falls at the origin")
	_free_session(session)
