## Snatcher (plan §5 — classic role: abductor). Area2D with fixed-step manual
## motion and a small explicit state machine (§10.4):
## PATROL -> DESCEND (reserved) -> ASCEND (carrying) -> escape.
## All targeting uses shortest wrapped distance via the coordinator/RingWorld.
## Fires an aimed shot every fire_interval at a player within fire_range (§5);
## escape still despawns without spawning the Ravager (roster arrives in M4) —
## the Settler MUTATED transition itself is fully implemented.
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

## §6.4 difficulty multiplier applied to movement and shot speed.
var speed_scale := 1.0

var balance: Resource  # SnatcherBalance
var coordinator: SettlerCoordinator

var _target: Node2D = null  # reserved/carried Settler
var _patrol_dir := 1
var _patrol_timer := 0.0
var _fire_timer := -1.0  # scheduled from gameplay_rng on the first armed tick


func setup(p_sim_x: float, p_sim_y: float, p_balance: Resource, p_coordinator: SettlerCoordinator, p_speed_scale := 1.0) -> void:
	sim_x = p_sim_x
	sim_y = p_sim_y
	balance = p_balance
	coordinator = p_coordinator
	hit_radius = balance.hit_radius
	speed_scale = p_speed_scale


## Advance one fixed step. player is the aim target (null while the player is
## dead — abduction continues, fire holds). Returns a fire request:
## {} or {sim_x, y, velocity}.
func tick(delta: float, ring: RingWorld, gameplay_rng: RandomNumberGenerator, player: Node2D = null) -> Dictionary:
	if not alive:
		return {}
	match state:
		State.PATROL:
			_patrol(delta, ring, gameplay_rng)
		State.DESCEND:
			_descend(delta, ring)
		State.ASCEND:
			_ascend(delta)
	if not alive:  # escaped during _ascend
		return {}
	return _try_fire(delta, ring, gameplay_rng, player)


func take_hit() -> void:
	if not alive:
		return
	alive = false
	# Releases a TARGETED Settler to SAFE or drops a carried one into FALLING.
	coordinator.carrier_destroyed(self)
	_target = null
	died.emit(self)


## Aimed fire (§5): every fire_interval seconds, a straight shot at the
## player's current position. First shots are desynced across the pack via
## gameplay_rng (§6.3 — AI timing never touches encounter_rng).
func _try_fire(delta: float, ring: RingWorld, gameplay_rng: RandomNumberGenerator, player: Node2D) -> Dictionary:
	if player == null:
		return {}
	if _fire_timer < 0.0:
		_fire_timer = gameplay_rng.randf_range(0.5, balance.fire_interval)
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return {}
	_fire_timer = balance.fire_interval
	var aim := Vector2(ring.wrapped_delta_x(sim_x, player.sim_x), player.position.y - sim_y)
	var reach := aim.length()
	if reach > balance.fire_range or reach < 1.0:
		return {}
	return {
		"sim_x": sim_x,
		"y": sim_y,
		"velocity": aim / reach * balance.shot_speed * speed_scale,
	}


func _patrol(delta: float, ring: RingWorld, gameplay_rng: RandomNumberGenerator) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		# Movement-jitter timing draws from gameplay_rng, never encounter_rng (§5).
		_patrol_dir = 1 if gameplay_rng.randf() < 0.5 else -1
		_patrol_timer = gameplay_rng.randf_range(balance.patrol_turn_min, balance.patrol_turn_max)
	sim_x = ring.normalize_x(sim_x + _patrol_dir * balance.patrol_speed * speed_scale * delta)
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
	var step: float = balance.descend_speed * speed_scale * delta
	sim_x = ring.normalize_x(sim_x + clampf(dx, -step, step))
	sim_y = move_toward(sim_y, grab_y, step)
	if absf(dx) <= balance.grab_radius and absf(sim_y - grab_y) < 1.0:
		coordinator.begin_carry(self)
		state = State.ASCEND


func _ascend(delta: float) -> void:
	sim_y -= balance.ascend_speed * speed_scale * delta
	if _target != null:
		_target.sim_x = sim_x
		_target.sim_y = sim_y + balance.carry_offset_y
	if sim_y <= balance.escape_y:
		alive = false
		coordinator.carrier_escaped(self)
		_target = null
		escaped.emit(self)
