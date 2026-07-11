## Settler self-driven behavior (§4.5): walking on terrain via gameplay_rng,
## falling physics with the survivable-fall rule, and the DELIVERED recovery
## timer — all through coordinator-owned transitions.
extends "res://tests/test_case.gd"

const RingWorldScript := preload("res://scripts/core/ring_world.gd")
const TerrainProfileScript := preload("res://scripts/core/terrain_profile.gd")
const CoordinatorScript := preload("res://scripts/core/settler_coordinator.gd")
const SettlerScript := preload("res://scripts/actors/settler.gd")
const SETTLER_SCENE := preload("res://scenes/actors/settler.tscn")
const SETTLER_BALANCE := preload("res://resources/balance/settler_balance.tres")

const W := 3840.0
const DT := 1.0 / 60.0


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	return rng


func _spawn(x: float, terrain: TerrainProfile, coordinator: SettlerCoordinator) -> Node2D:
	var settler: Node2D = SETTLER_SCENE.instantiate()
	scene_tree.root.add_child(settler)
	settler.setup(x, SETTLER_BALANCE, terrain)
	coordinator.register_settler(settler)
	return settler


func _free_node(node: Node2D) -> void:
	scene_tree.root.remove_child(node)
	node.free()


func test_walks_on_terrain() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var coordinator: SettlerCoordinator = CoordinatorScript.new(ring, SETTLER_BALANCE, 1)
	var settler := _spawn(1000.0, terrain, coordinator)
	var rng := _rng()
	var moved := false
	var start_x: float = settler.sim_x
	for i in 600:  # 10 s
		settler.tick(DT, ring, terrain, rng)
		if absf(ring.wrapped_delta_x(start_x, settler.sim_x)) > 5.0:
			moved = true
		var expected_y: float = terrain.get_surface_y(settler.sim_x) - SETTLER_BALANCE.ground_offset
		assert_true(absf(settler.sim_y - expected_y) < 0.5,
				"stays glued to the surface while walking")
	assert_true(moved, "walking actually moves the settler")
	assert_eq(settler.state, SettlerScript.State.SAFE, "walking never changes state")
	_free_node(settler)


func test_short_fall_lands_safe() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var coordinator: SettlerCoordinator = CoordinatorScript.new(ring, SETTLER_BALANCE, 1)
	var settler := _spawn(500.0, terrain, coordinator)
	var owner := RefCounted.new()
	coordinator.try_reserve(owner, 500.0)
	coordinator.begin_carry(owner)
	settler.sim_y = terrain.get_surface_y(settler.sim_x) - SETTLER_BALANCE.ground_offset - 80.0
	coordinator.carrier_destroyed(owner)
	assert_eq(settler.state, SettlerScript.State.FALLING, "released into FALLING")
	var rng := _rng()
	for i in 300:
		settler.tick(DT, ring, terrain, rng)
		if settler.state != SettlerScript.State.FALLING:
			break
	assert_eq(settler.state, SettlerScript.State.SAFE, "80px fall survives (limit 130)")
	_free_node(settler)


func test_high_fall_is_lost() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var coordinator: SettlerCoordinator = CoordinatorScript.new(ring, SETTLER_BALANCE, 1)
	var settler := _spawn(500.0, terrain, coordinator)
	var owner := RefCounted.new()
	coordinator.try_reserve(owner, 500.0)
	coordinator.begin_carry(owner)
	settler.sim_y = 150.0  # hundreds of px up
	coordinator.carrier_destroyed(owner)
	var rng := _rng()
	for i in 600:
		settler.tick(DT, ring, terrain, rng)
		if settler.state != SettlerScript.State.FALLING:
			break
	assert_eq(settler.state, SettlerScript.State.LOST, "high fall is lethal")
	assert_false(settler.is_alive(), "lost settler is not alive")
	_free_node(settler)


func test_delivered_recovers_to_safe() -> void:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var coordinator: SettlerCoordinator = CoordinatorScript.new(ring, SETTLER_BALANCE, 1)
	var settler := _spawn(500.0, terrain, coordinator)
	var owner := RefCounted.new()
	coordinator.try_reserve(owner, 500.0)
	coordinator.begin_carry(owner)
	coordinator.carrier_destroyed(owner)
	coordinator.catch_settler(settler)
	coordinator.deliver_settler(settler, terrain.get_surface_y(settler.sim_x) - SETTLER_BALANCE.ground_offset)
	assert_eq(settler.state, SettlerScript.State.DELIVERED, "protected on delivery")
	var rng := _rng()
	var ticks := 0
	while settler.state == SettlerScript.State.DELIVERED and ticks < 300:
		settler.tick(DT, ring, terrain, rng)
		ticks += 1
	assert_eq(settler.state, SettlerScript.State.SAFE, "recovers to SAFE")
	var seconds := ticks * DT
	assert_true(seconds >= SETTLER_BALANCE.delivered_duration - 0.1
			and seconds <= SETTLER_BALANCE.delivered_duration + 0.1,
			"protection lasts ~%.1fs (took %.2fs)" % [SETTLER_BALANCE.delivered_duration, seconds])
	_free_node(settler)
