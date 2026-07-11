## SettlerCoordinator: central ownership (§4.5) — reservation conflicts,
## abduction cap, nearest-by-wrapped-distance selection across the seam,
## and every coordinator-owned transition.
extends "res://tests/test_case.gd"

const RingWorldScript := preload("res://scripts/core/ring_world.gd")
const TerrainProfileScript := preload("res://scripts/core/terrain_profile.gd")
const CoordinatorScript := preload("res://scripts/core/settler_coordinator.gd")
const SettlerScript := preload("res://scripts/actors/settler.gd")
const SETTLER_SCENE := preload("res://scenes/actors/settler.tscn")
const SETTLER_BALANCE := preload("res://resources/balance/settler_balance.tres")

const W := 3840.0

var _nodes: Array = []


func _make(cap: int, settler_xs: Array) -> SettlerCoordinator:
	var ring: RingWorld = RingWorldScript.new(W)
	var terrain: TerrainProfile = TerrainProfileScript.new(W)
	var coordinator: SettlerCoordinator = CoordinatorScript.new(ring, SETTLER_BALANCE, cap)
	for x in settler_xs:
		var settler: Node2D = SETTLER_SCENE.instantiate()
		scene_tree.root.add_child(settler)
		settler.setup(x, SETTLER_BALANCE, terrain)
		coordinator.register_settler(settler)
		_nodes.append(settler)
	return coordinator


func _cleanup() -> void:
	for node in _nodes:
		scene_tree.root.remove_child(node)
		node.free()
	_nodes.clear()


func test_reservation_conflict_single_owner() -> void:
	var coordinator := _make(2, [1000.0])
	var owner_a := RefCounted.new()
	var owner_b := RefCounted.new()
	var settler := coordinator.try_reserve(owner_a, 900.0)
	assert_true(settler != null, "first owner reserves")
	assert_eq(settler.state, SettlerScript.State.TARGETED, "reserved settler is TARGETED")
	assert_true(coordinator.try_reserve(owner_b, 900.0) == null,
			"second owner cannot claim the only (already reserved) settler")
	assert_eq(coordinator.try_reserve(owner_a, 900.0), settler,
			"re-request by the same owner returns its existing reservation")
	_cleanup()


func test_abduction_cap() -> void:
	var coordinator := _make(1, [500.0, 2500.0])
	var owner_a := RefCounted.new()
	var owner_b := RefCounted.new()
	assert_true(coordinator.try_reserve(owner_a, 400.0) != null, "first abduction allowed")
	assert_true(coordinator.try_reserve(owner_b, 2400.0) == null,
			"cap of 1 blocks a second concurrent abduction")
	coordinator.release_reservation(owner_a)
	assert_true(coordinator.try_reserve(owner_b, 2400.0) != null,
			"slot frees after release")
	_cleanup()


func test_nearest_selection_across_seam() -> void:
	var coordinator := _make(2, [300.0, 3700.0])
	var owner := RefCounted.new()
	var settler := coordinator.try_reserve(owner, 50.0)
	assert_almost_eq(settler.sim_x, 3700.0, 0.001,
			"picks the settler 190px across the seam over the one 250px away")
	_cleanup()


func test_release_returns_to_safe() -> void:
	var coordinator := _make(1, [800.0])
	var owner := RefCounted.new()
	var settler := coordinator.try_reserve(owner, 700.0)
	coordinator.release_reservation(owner)
	assert_eq(settler.state, SettlerScript.State.SAFE, "released reservation restores SAFE")
	assert_eq(coordinator.active_abductions(), 0, "no active abductions remain")
	_cleanup()


func test_carry_and_carrier_destroyed_releases_falling() -> void:
	var coordinator := _make(1, [800.0])
	var owner := RefCounted.new()
	var settler := coordinator.try_reserve(owner, 700.0)
	coordinator.begin_carry(owner)
	assert_eq(settler.state, SettlerScript.State.CARRIED_BY_ENEMY, "grab completes")
	assert_true(coordinator.has_unresolved_transitions(), "carry blocks wave clear")
	coordinator.carrier_destroyed(owner)
	assert_eq(settler.state, SettlerScript.State.FALLING,
			"destroying the carrier releases the settler into FALLING")
	_cleanup()


func test_carrier_destroyed_before_grab_restores_safe() -> void:
	var coordinator := _make(1, [800.0])
	var owner := RefCounted.new()
	var settler := coordinator.try_reserve(owner, 700.0)
	coordinator.carrier_destroyed(owner)
	assert_eq(settler.state, SettlerScript.State.SAFE,
			"killing a snatcher that only reserved (not grabbed) frees the settler unharmed")
	_cleanup()


func test_escape_mutates() -> void:
	var coordinator := _make(1, [800.0])
	var owner := RefCounted.new()
	var settler := coordinator.try_reserve(owner, 700.0)
	coordinator.begin_carry(owner)
	coordinator.carrier_escaped(owner)
	assert_eq(settler.state, SettlerScript.State.MUTATED, "escape mutates the settler")
	assert_false(settler.is_alive(), "mutated settler no longer counts as alive")
	assert_eq(coordinator.alive_count(), 0, "population reflects the loss")
	_cleanup()


func test_catch_and_deliver_flow() -> void:
	var coordinator := _make(1, [800.0])
	var owner := RefCounted.new()
	var settler := coordinator.try_reserve(owner, 700.0)
	coordinator.begin_carry(owner)
	coordinator.carrier_destroyed(owner)
	coordinator.catch_settler(settler)
	assert_eq(settler.state, SettlerScript.State.CARRIED_BY_PLAYER, "player catch")
	assert_true(coordinator.has_unresolved_transitions(), "player carry blocks wave clear")
	coordinator.deliver_settler(settler, 592.0)
	assert_eq(settler.state, SettlerScript.State.DELIVERED, "delivery protects briefly")
	assert_almost_eq(settler.sim_y, 592.0, 0.001, "delivered onto the surface")
	assert_false(coordinator.has_unresolved_transitions(),
			"DELIVERED is resolved — wave may clear")
	_cleanup()


func test_catch_requires_falling() -> void:
	var coordinator := _make(1, [800.0])
	var settler: Node2D = coordinator.settlers[0]
	coordinator.catch_settler(settler)
	assert_eq(settler.state, SettlerScript.State.SAFE,
			"catching a grounded settler is a no-op")
	_cleanup()


func test_ground_impact_severity() -> void:
	var coordinator := _make(2, [800.0, 2000.0])
	var owner := RefCounted.new()
	var short_fall := coordinator.try_reserve(owner, 800.0)
	coordinator.begin_carry(owner)
	coordinator.carrier_destroyed(owner)
	coordinator.ground_impact(short_fall, SETTLER_BALANCE.safe_fall_distance - 10.0)
	assert_eq(short_fall.state, SettlerScript.State.SAFE, "short fall survives")

	var owner_b := RefCounted.new()
	var long_fall := coordinator.try_reserve(owner_b, 2000.0)
	coordinator.begin_carry(owner_b)
	coordinator.carrier_destroyed(owner_b)
	coordinator.ground_impact(long_fall, SETTLER_BALANCE.safe_fall_distance + 10.0)
	assert_eq(long_fall.state, SettlerScript.State.LOST, "long fall is lethal")
	assert_eq(coordinator.alive_count(), 1, "one settler left alive")
	_cleanup()
