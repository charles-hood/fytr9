## Drives the real world.tscn headlessly through its fixed-step pipeline:
## seam-crossing shot hits, anchored placement across the seam, shot
## lifetime expiry, terrain impact, dummy respawn, and anchor rebase.
extends "res://tests/test_case.gd"

const WORLD_SCENE := preload("res://scenes/game/world.tscn")

const W := 3840.0
const DT := 1.0 / 60.0


func _spawn_world() -> Node2D:
	var world: Node2D = WORLD_SCENE.instantiate()
	scene_tree.root.add_child(world)
	return world


func _free_world(world: Node2D) -> void:
	scene_tree.root.remove_child(world)
	world.free()


func _step(world: Node2D, ticks: int) -> void:
	for i in ticks:
		world._physics_process(DT)


func test_shot_hits_dummy_across_seam() -> void:
	var world := _spawn_world()
	var seam_dummy = world.targets[0]
	assert_almost_eq(seam_dummy.sim_x, 0.0, 0.001, "first dummy sits exactly on the seam")
	world.spawn_player_shot(W - 30.0, seam_dummy.sim_y, 1)
	_step(world, 5)
	assert_false(seam_dummy.alive, "shot fired before the seam kills the dummy after it")
	assert_eq(world.shots.size(), 0, "shot is consumed by the hit — no double kill")
	_free_world(world)


func test_shot_does_not_hit_wrong_altitude() -> void:
	var world := _spawn_world()
	var seam_dummy = world.targets[0]
	world.spawn_player_shot(W - 30.0, seam_dummy.sim_y - 100.0, 1)
	_step(world, 5)
	assert_true(seam_dummy.alive, "shot 100px above passes clean")
	_free_world(world)


func test_placement_across_seam_is_shortest_route() -> void:
	var world := _spawn_world()
	# Player anchor starts at scene/sim x 640. The dummy at ~sim 3799.7
	# (fraction 0.9895) must be placed just left of the seam, not a full
	# world away.
	var near_seam_dummy = world.targets[2]
	_step(world, 1)
	var expected: float = world.player.position.x \
			+ world.ring.wrapped_delta_x(world.player.sim_x, near_seam_dummy.sim_x)
	assert_almost_eq(near_seam_dummy.position.x, expected, 0.001, "anchored placement")
	assert_true(near_seam_dummy.position.x < world.player.position.x,
			"near-seam dummy appears a short hop left of the player, not ~3800px right")
	assert_true(world.player.position.x - near_seam_dummy.position.x < 800.0,
			"short route, not the long way around")
	_free_world(world)


func test_shot_expires_by_lifetime() -> void:
	var world := _spawn_world()
	world.spawn_player_shot(640.0, 100.0, 1)  # altitude clear of every dummy
	assert_eq(world.shots.size(), 1, "shot spawned")
	_step(world, int(1.3 / DT))
	assert_eq(world.shots.size(), 0, "shot expired by lifetime (§4.3 cap rule)")
	_free_world(world)


func test_shot_dies_on_terrain() -> void:
	var world := _spawn_world()
	world.spawn_player_shot(640.0, 690.0, 1)  # below the lowest valley floor
	_step(world, 2)
	assert_eq(world.shots.size(), 0, "shot absorbed by terrain")
	_free_world(world)


func test_dummy_respawns() -> void:
	var world := _spawn_world()
	var dummy = world.targets[3]
	dummy.take_hit()
	assert_false(dummy.alive, "dummy down")
	_step(world, int(2.2 / DT))
	assert_true(dummy.alive, "flight-lab dummy respawns")
	_free_world(world)


func test_rebase_keeps_camera_player_relation() -> void:
	var world := _spawn_world()
	_step(world, 2)
	world.player.position.x = 17.0 * W + 123.0
	world.camera.position.x = world.player.position.x + 50.0
	var relative: float = world.camera.position.x - world.player.position.x
	world._maybe_rebase()
	assert_true(absf(world.player.position.x) < W, "anchor rebased near origin")
	assert_almost_eq(world.camera.position.x - world.player.position.x, relative, 0.001,
			"camera shifted by the same amount — rebase is invisible")
	_free_world(world)
