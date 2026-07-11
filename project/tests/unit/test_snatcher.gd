## Snatcher lifecycle (§5): patrol -> reserve -> descend -> grab -> ascend ->
## escape/mutate, plus destruction mid-carry releasing the Settler.
extends "res://tests/test_case.gd"

const RingWorldScript := preload("res://scripts/core/ring_world.gd")
const TerrainProfileScript := preload("res://scripts/core/terrain_profile.gd")
const CoordinatorScript := preload("res://scripts/core/settler_coordinator.gd")
const SettlerScript := preload("res://scripts/actors/settler.gd")
const SnatcherScript := preload("res://scripts/actors/enemies/snatcher.gd")
const SETTLER_SCENE := preload("res://scenes/actors/settler.tscn")
const SNATCHER_SCENE := preload("res://scenes/actors/enemies/snatcher.tscn")
const SETTLER_BALANCE := preload("res://resources/balance/settler_balance.tres")
const SNATCHER_BALANCE := preload("res://resources/balance/enemies/snatcher_balance.tres")

const W := 3840.0
const DT := 1.0 / 60.0

var _nodes: Array = []


func _build() -> Dictionary:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var coordinator: SettlerCoordinator = CoordinatorScript.new(ring, SETTLER_BALANCE, 1)
	var settler: Node2D = SETTLER_SCENE.instantiate()
	scene_tree.root.add_child(settler)
	settler.setup(1200.0, SETTLER_BALANCE, terrain)
	coordinator.register_settler(settler)
	var snatcher: Area2D = SNATCHER_SCENE.instantiate()
	scene_tree.root.add_child(snatcher)
	snatcher.setup(900.0, 150.0, SNATCHER_BALANCE, coordinator)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	_nodes = [settler, snatcher]
	return {"ring": ring, "terrain": terrain, "coordinator": coordinator,
			"settler": settler, "snatcher": snatcher, "rng": rng}


func _cleanup() -> void:
	for node in _nodes:
		scene_tree.root.remove_child(node)
		node.free()
	_nodes.clear()


func _tick_until(ctx: Dictionary, predicate: Callable, max_ticks: int) -> int:
	var ticks := 0
	while ticks < max_ticks:
		ctx["snatcher"].tick(DT, ctx["ring"], ctx["rng"])
		ctx["settler"].tick(DT, ctx["ring"], ctx["terrain"], ctx["rng"])
		ticks += 1
		if predicate.call():
			return ticks
	return ticks


func test_full_abduction_to_mutation() -> void:
	var ctx := _build()
	var snatcher: Area2D = ctx["snatcher"]
	var settler: Node2D = ctx["settler"]

	_tick_until(ctx, func(): return snatcher.state == SnatcherScript.State.DESCEND, 120)
	assert_eq(snatcher.state, SnatcherScript.State.DESCEND, "reserves and descends quickly")
	assert_eq(settler.state, SettlerScript.State.TARGETED, "settler reserved")

	_tick_until(ctx, func(): return settler.state == SettlerScript.State.CARRIED_BY_ENEMY, 900)
	assert_eq(settler.state, SettlerScript.State.CARRIED_BY_ENEMY, "grab completes")
	assert_eq(snatcher.state, SnatcherScript.State.ASCEND, "ascends after the grab")

	var escaped_count := [0]
	snatcher.escaped.connect(func(_s): escaped_count[0] += 1)
	_tick_until(ctx, func(): return settler.state == SettlerScript.State.MUTATED, 900)
	assert_eq(settler.state, SettlerScript.State.MUTATED, "escape mutates the settler")
	assert_eq(escaped_count[0], 1, "escaped signal fired exactly once")
	assert_false(snatcher.alive, "escaped snatcher leaves the field")
	assert_true(snatcher.sim_y <= SNATCHER_BALANCE.escape_y + 1.0,
			"escape happened at the upper boundary")
	_cleanup()


func test_carried_settler_tracks_carrier() -> void:
	var ctx := _build()
	var snatcher: Area2D = ctx["snatcher"]
	var settler: Node2D = ctx["settler"]
	_tick_until(ctx, func(): return settler.state == SettlerScript.State.CARRIED_BY_ENEMY, 900)
	for i in 30:
		snatcher.tick(DT, ctx["ring"], ctx["rng"])
	assert_almost_eq(settler.sim_x, snatcher.sim_x, 0.001, "carried settler follows x")
	assert_almost_eq(settler.sim_y, snatcher.sim_y + SNATCHER_BALANCE.carry_offset_y, 0.001,
			"carried settler hangs below the carrier")
	_cleanup()


func test_kill_mid_carry_drops_settler() -> void:
	var ctx := _build()
	var snatcher: Area2D = ctx["snatcher"]
	var settler: Node2D = ctx["settler"]
	_tick_until(ctx, func(): return settler.state == SettlerScript.State.CARRIED_BY_ENEMY, 900)
	var died_count := [0]
	snatcher.died.connect(func(_s): died_count[0] += 1)
	snatcher.take_hit()
	assert_eq(settler.state, SettlerScript.State.FALLING, "killed carrier drops the settler")
	assert_eq(died_count[0], 1, "died signal fired once")
	snatcher.take_hit()
	assert_eq(died_count[0], 1, "second hit on a dead snatcher does nothing")
	_cleanup()


func test_kill_during_descent_frees_reservation() -> void:
	var ctx := _build()
	var snatcher: Area2D = ctx["snatcher"]
	var settler: Node2D = ctx["settler"]
	_tick_until(ctx, func(): return snatcher.state == SnatcherScript.State.DESCEND, 120)
	snatcher.take_hit()
	assert_eq(settler.state, SettlerScript.State.SAFE,
			"reservation released, settler unharmed")
	assert_eq(ctx["coordinator"].active_abductions(), 0, "abduction slot freed")
	_cleanup()
