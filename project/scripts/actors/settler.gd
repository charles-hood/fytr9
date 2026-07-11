## Settler (plan §4.5, §10.4) — kinematic Node2D with an explicit enum state
## machine. Ownership and every state change go through SettlerCoordinator
## (§4.5: "no actor may claim a Settler directly"); apply_state() is called
## ONLY by the coordinator. This node handles its own SAFE/TARGETED walking,
## FALLING physics, and the DELIVERED recovery timer — reporting outcomes
## back to the coordinator rather than transitioning itself.
extends Node2D

enum State {
	SAFE,
	TARGETED,
	CARRIED_BY_ENEMY,
	FALLING,
	CARRIED_BY_PLAYER,
	DELIVERED,
	LOST,
	MUTATED,
}

signal state_changed(settler: Node2D, from_state: int, to_state: int)

var sim_x := 0.0
var sim_y := 0.0
var state: State = State.SAFE
var balance: Resource  # SettlerBalance

## Vertical position where the current fall began (for the survivable-fall
## rule, §4.5).
var fall_start_y := 0.0

var _fall_velocity := 0.0
var _walk_dir := 0
var _walk_timer := 0.0
var _delivered_timer := 0.0

var _coordinator: RefCounted  # SettlerCoordinator; set at registration

@onready var _body: Node2D = $Body


func setup(p_sim_x: float, p_balance: Resource, terrain: TerrainProfile) -> void:
	balance = p_balance
	sim_x = p_sim_x
	sim_y = terrain.get_surface_y(sim_x) - balance.ground_offset


## Called only by SettlerCoordinator at registration.
func bind_coordinator(coordinator: RefCounted) -> void:
	_coordinator = coordinator


## Called ONLY by SettlerCoordinator (§4.5 central ownership).
func apply_state(new_state: State) -> void:
	var old := state
	state = new_state
	match new_state:
		State.FALLING:
			fall_start_y = sim_y
			_fall_velocity = 0.0
		State.DELIVERED:
			_delivered_timer = balance.delivered_duration
		State.LOST, State.MUTATED:
			visible = false
	state_changed.emit(self, old, new_state)


func is_alive() -> bool:
	return state != State.LOST and state != State.MUTATED


func tick(delta: float, ring: RingWorld, terrain: TerrainProfile, gameplay_rng: RandomNumberGenerator) -> void:
	match state:
		State.SAFE, State.TARGETED:
			_walk(delta, ring, terrain, gameplay_rng)
		State.FALLING:
			_fall(delta, terrain)
		State.DELIVERED:
			_delivered_timer -= delta
			if _delivered_timer <= 0.0:
				_coordinator.delivered_recovered(self)
		_:
			pass  # carried states are positioned by the carrier/world


func _walk(delta: float, ring: RingWorld, terrain: TerrainProfile, gameplay_rng: RandomNumberGenerator) -> void:
	_walk_timer -= delta
	if _walk_timer <= 0.0:
		# Direction/interval choices draw from gameplay_rng (§4.5, §6.3).
		_walk_dir = gameplay_rng.randi_range(-1, 1)
		_walk_timer = gameplay_rng.randf_range(balance.walk_interval_min, balance.walk_interval_max)
	sim_x = ring.normalize_x(sim_x + _walk_dir * balance.walk_speed * delta)
	sim_y = terrain.get_surface_y(sim_x) - balance.ground_offset


func _fall(delta: float, terrain: TerrainProfile) -> void:
	_fall_velocity = minf(_fall_velocity + balance.fall_gravity * delta, balance.max_fall_speed)
	sim_y += _fall_velocity * delta
	var ground_y: float = terrain.get_surface_y(sim_x) - balance.ground_offset
	if sim_y >= ground_y:
		sim_y = ground_y
		_coordinator.ground_impact(self, ground_y - fall_start_y)
