## Player flight model against the §4.2 envelope: time to max speed
## (0.40-0.55 s), full-speed reversal (0.50-0.70 s), release damping,
## vertical band clamping, ring wrapping, and Arc Lance cadence.
## Deterministic: tick() takes synthetic input, no Input singleton.
extends "res://tests/test_case.gd"

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const RingWorldScript := preload("res://scripts/core/ring_world.gd")
const TerrainProfileScript := preload("res://scripts/core/terrain_profile.gd")
const WORLD_BALANCE := preload("res://resources/balance/world_balance.tres")

const W := 3840.0
const DT := 1.0 / 60.0


func _spawn_player() -> CharacterBody2D:
	var player: CharacterBody2D = PLAYER_SCENE.instantiate()
	scene_tree.root.add_child(player)
	player.position = Vector2(640.0, 300.0)
	player.sim_x = 640.0
	return player


func _free_player(player: CharacterBody2D) -> void:
	scene_tree.root.remove_child(player)
	player.free()


func test_time_to_max_speed() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var player := _spawn_player()
	var ticks := 0
	while player.velocity.x < player.balance.max_horizontal_speed - 1.0 and ticks < 300:
		player.tick(DT, Vector2(1, 0), false, ring, terrain, WORLD_BALANCE)
		ticks += 1
	var seconds := ticks * DT
	assert_true(seconds >= 0.40 and seconds <= 0.55,
			"time to max speed %.3fs within §4.2 range" % seconds)
	assert_eq(player.facing, 1, "facing follows thrust direction")
	_free_player(player)


func test_full_speed_reversal_time() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var player := _spawn_player()
	for i in 120:
		player.tick(DT, Vector2(1, 0), false, ring, terrain, WORLD_BALANCE)
	var ticks := 0
	while player.velocity.x > -(player.balance.max_horizontal_speed - 1.0) and ticks < 300:
		player.tick(DT, Vector2(-1, 0), false, ring, terrain, WORLD_BALANCE)
		ticks += 1
	var seconds := ticks * DT
	assert_true(seconds >= 0.50 and seconds <= 0.70,
			"full reversal %.3fs within §4.2 range" % seconds)
	assert_eq(player.facing, -1, "facing flips on reversal")
	_free_player(player)


func test_release_damping_coasts_to_stop() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var player := _spawn_player()
	for i in 120:
		player.tick(DT, Vector2(1, 0), false, ring, terrain, WORLD_BALANCE)
	var ticks := 0
	while player.velocity.x > 0.0 and ticks < 600:
		player.tick(DT, Vector2.ZERO, false, ring, terrain, WORLD_BALANCE)
		ticks += 1
	var seconds := ticks * DT
	assert_true(seconds > 0.3, "damped stop is inertial, not instant (%.3fs)" % seconds)
	assert_true(seconds < 1.5, "damped stop is moderate, not endless drift (%.3fs)" % seconds)
	_free_player(player)


func test_vertical_band_clamps() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var player := _spawn_player()
	for i in 240:
		player.tick(DT, Vector2(0, 1), false, ring, terrain, WORLD_BALANCE)
	var floor_y: float = terrain.get_surface_y(player.sim_x) - WORLD_BALANCE.terrain_clearance
	assert_almost_eq(player.position.y, floor_y, 0.001, "clamped just above terrain")
	for i in 240:
		player.tick(DT, Vector2(0, -1), false, ring, terrain, WORLD_BALANCE)
	assert_almost_eq(player.position.y, WORLD_BALANCE.min_player_y, 0.001,
			"clamped at top of band")
	_free_player(player)


func test_position_wraps_on_ring() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var player := _spawn_player()
	player.position.x = W - 5.0
	for i in 120:
		player.tick(DT, Vector2(1, 0), false, ring, terrain, WORLD_BALANCE)
	assert_true(player.position.x > W, "scene x stays continuous past the seam")
	assert_almost_eq(player.sim_x, ring.normalize_x(player.position.x), 0.001,
			"sim x tracks normalized ring position")
	assert_true(player.sim_x >= 0.0 and player.sim_x < W, "sim x within [0,W)")
	_free_player(player)


func test_arc_lance_cadence() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var player := _spawn_player()
	var fired := 0
	var first_request: Dictionary = {}
	for i in 60:
		var request: Dictionary = player.tick(DT, Vector2.ZERO, true, ring, terrain, WORLD_BALANCE)
		if not request.is_empty():
			fired += 1
			if first_request.is_empty():
				first_request = request
	assert_true(fired >= 8 and fired <= 10,
			"%d shots in 1s matches 8-10/s cadence (§4.2)" % fired)
	assert_eq(int(first_request["direction"]), 1, "shots fire in facing direction")
	assert_almost_eq(first_request["sim_x"],
			ring.normalize_x(player.sim_x + player.balance.muzzle_offset), 0.001,
			"muzzle offset ahead of ship")
	_free_player(player)
