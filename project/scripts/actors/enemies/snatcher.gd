## Snatcher (plan §5 — classic role: abductor). Area2D with fixed-step manual
## motion and a small explicit state machine (§10.4):
## PATROL -> DESCEND (reserved) -> ASCEND (carrying) -> escape.
## All targeting uses shortest wrapped distance via the coordinator/RingWorld.
##
## Milestone 2 scope: no aimed shots (player death arrives in M3) and escape
## despawns without spawning the Ravager (roster arrives in M4) — the Settler
## MUTATED transition itself is fully implemented. See docs/DECISIONS.md.
extends Area2D

const Settler := preload("res://scripts/actors/settler.gd")

enum State { PATROL, DESCEND, ASCEND }

signal died(snatcher: Area2D)
signal escaped(snatcher: Area2D)

var sim_x := 0.0
var sim_y := 0.0
var alive := true
var hit_radius := 16.0
var state: State = State.PATROL

var balance: Resource  # SnatcherBalance
var coordinator: SettlerCoordinator

var _target: Node2D = null  # reserved/carried Settler
var _patrol_dir := 1
var _patrol_timer := 0.0


func setup(p_sim_x: float, p_sim_y: float, p_balance: Resource, p_coordinator: SettlerCoordinator) -> void:
	sim_x = p_sim_x
	sim_y = p_sim_y
	balance = p_balance
	coordinator = p_coordinator
	hit_radius = balance.hit_radius


func tick(delta: float, ring: RingWorld, gameplay_rng: RandomNumberGenerator) -> void:
	if not alive:
		return
	match state:
		State.PATROL:
			_patrol(delta, ring, gameplay_rng)
		State.DESCEND:
			_descend(delta, ring)
		State.ASCEND:
			_ascend(delta)


func take_hit() -> void:
	if not alive:
		return
	alive = false
	# Releases a TARGETED Settler to SAFE or drops a carried one into FALLING.
	coordinator.carrier_destroyed(self)
	_target = null
	died.emit(self)


func _patrol(delta: float, ring: RingWorld, gameplay_rng: RandomNumberGenerator) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		# Movement-jitter timing draws from gameplay_rng, never encounter_rng (§5).
		_patrol_dir = 1 if gameplay_rng.randf() < 0.5 else -1
		_patrol_timer = gameplay_rng.randf_range(balance.patrol_turn_min, balance.patrol_turn_max)
	sim_x = ring.normalize_x(sim_x + _patrol_dir * balance.patrol_speed * delta)
	sim_y = clampf(sim_y, balance.patrol_y_min, balance.patrol_y_max)

	var settler := coordinator.try_reserve(self, sim_x)
	if settler != null:
		_target = settler
		state = State.DESCEND


func _descend(delta: float, ring: RingWorld) -> void:
	if _target == null or _target.state != Settler.State.TARGETED:
		# Lost the reservation (should not happen unshot; defensive).
		coordinator.release_reservation(self)
		_target = null
		state = State.PATROL
		return
	var grab_y: float = _target.sim_y - balance.grab_offset_y
	var dx: float = ring.wrapped_delta_x(sim_x, _target.sim_x)
	var step: float = balance.descend_speed * delta
	sim_x = ring.normalize_x(sim_x + clampf(dx, -step, step))
	sim_y = move_toward(sim_y, grab_y, step)
	if absf(dx) <= balance.grab_radius and absf(sim_y - grab_y) < 1.0:
		coordinator.begin_carry(self)
		state = State.ASCEND


func _ascend(delta: float) -> void:
	sim_y -= balance.ascend_speed * delta
	if _target != null:
		_target.sim_x = sim_x
		_target.sim_y = sim_y + balance.carry_offset_y
	if sim_y <= balance.escape_y:
		alive = false
		coordinator.carrier_escaped(self)
		_target = null
		escaped.emit(self)
