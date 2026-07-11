## World mechanics through the real session: seam-crossing shot hits, anchored
## placement, shot lifetime/terrain absorption, and the anchor rebase.
extends "res://tests/test_case.gd"

const SESSION_SCENE := preload("res://scenes/game/game_session.tscn")

const W := 3840.0
const DT := 1.0 / 60.0


func _spawn_world() -> Array:
	var session: Node2D = SESSION_SCENE.instantiate()
	session.get_node("RunController").fixed_seed = 31337
	scene_tree.root.add_child(session)
	return [session, session.get_node("World")]


func _free_session(session: Node2D) -> void:
	scene_tree.root.remove_child(session)
	session.free()


func _step(world: Node2D, ticks: int) -> void:
	for i in ticks:
		world._physics_process(DT)


func test_shot_hits_snatcher_across_seam() -> void:
	var pair := _spawn_world()
	var world: Node2D = pair[1]
	world.spawn_snatcher(5.0)
	var snatcher: Area2D = world.enemies[0]
	snatcher.sim_y = 150.0  # inside the patrol band, so its tick won't move it
	world.spawn_player_shot(W - 30.0, 150.0, 1)
	_step(world, 5)
	assert_false(snatcher.alive, "shot fired before the seam kills the snatcher after it")
	assert_false(world.enemies.has(snatcher), "dead snatcher removed from the field")
	assert_eq(world.shots.size(), 0, "shot consumed by the hit — no double kill")
	_free_session(pair[0])


func test_placement_across_seam_is_shortest_route() -> void:
	var pair := _spawn_world()
	var world: Node2D = pair[1]
	world.spawn_snatcher(W - 40.0)
	var snatcher: Area2D = world.enemies[0]
	_step(world, 1)
	var expected: float = world.player.position.x \
			+ world.ring.wrapped_delta_x(world.player.sim_x, snatcher.sim_x)
	assert_almost_eq(snatcher.position.x, expected, 0.001, "anchored placement")
	assert_true(absf(world.player.position.x - snatcher.position.x) < 800.0,
			"near-seam enemy placed a short hop away, not a world away")
	_free_session(pair[0])


func test_shot_expires_by_lifetime() -> void:
	var pair := _spawn_world()
	var world: Node2D = pair[1]
	world.spawn_player_shot(640.0, 30.0, 1)  # altitude above any patrol band
	assert_eq(world.shots.size(), 1, "shot spawned")
	_step(world, int(1.3 / DT))
	assert_eq(world.shots.size(), 0, "shot expired by lifetime (§4.3 cap rule)")
	_free_session(pair[0])


func test_shot_dies_on_terrain() -> void:
	var pair := _spawn_world()
	var world: Node2D = pair[1]
	world.spawn_player_shot(640.0, 690.0, 1)  # below the lowest valley floor
	_step(world, 2)
	assert_eq(world.shots.size(), 0, "shot absorbed by terrain")
	_free_session(pair[0])


func test_rebase_keeps_camera_player_relation() -> void:
	var pair := _spawn_world()
	var world: Node2D = pair[1]
	_step(world, 2)
	world.player.position.x = 17.0 * W + 123.0
	world.camera.position.x = world.player.position.x + 50.0
	var relative: float = world.camera.position.x - world.player.position.x
	world._maybe_rebase()
	assert_true(absf(world.player.position.x) < W, "anchor rebased near origin")
	assert_almost_eq(world.camera.position.x - world.player.position.x, relative, 0.001,
			"camera shifted by the same amount — rebase is invisible")

	# A full tick that rebases must also render entities relative to the new
	# anchor — placing before the rebase left everything a world width away
	# for one frame (M3 GLM review, nit 3).
	world.spawn_snatcher(world.ring.normalize_x(world.player.sim_x + 300.0))
	world.player.position.x = 17.0 * W + 123.0
	world.player.sim_x = world.ring.normalize_x(world.player.position.x)
	world._physics_process(DT)
	assert_true(absf(world.player.position.x) < W, "tick performed the rebase")
	for enemy in world.enemies:
		assert_true(absf(enemy.position.x - world.player.position.x) <= W / 2.0 + 1.0,
				"entities placed against the rebased anchor in the same tick")
	_free_session(pair[0])
