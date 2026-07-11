## Fytr9 player craft (plan §4.2, §4.4, §10.4). Deterministic and headless-
## testable: GameWorld reads Input and drives tick() every physics frame —
## this script never touches the Input singleton or the world directly.
## Lethality decisions (terrain, contact, enemy fire) also live in GameWorld;
## this script owns only the craft's own state: movement, firing cadence,
## alive/dead, and the invulnerability/respawn timers.
##
## position.x is CONTINUOUS (unwrapped) scene x — the anchor the rest of the
## world is placed around (see GameWorld / docs/DECISIONS.md). sim_x is the
## normalized ring position.
extends CharacterBody2D

@export var balance: Resource  # PlayerBalance

var sim_x := 0.0
var facing := 1
var alive := true

## While positive the craft cannot be destroyed (respawn/hyperspace grace,
## §4.2/§4.3). Ticks down in tick().
var invuln_timer := 0.0

## Set each alive tick: the craft reached the terrain-clearance floor this
## step. GameWorld decides whether that is lethal (§4.2 per difficulty).
var touched_terrain := false

var _fire_cooldown := 0.0
var _respawn_timer := 0.0

@onready var _visual: Node2D = $Visual


## Advance one fixed step. move_input is pre-read axis input (-1..1 each),
## fire_held is the fire action state. Returns a fire request:
## {} when not firing, else {sim_x, y, direction}.
func tick(delta: float, move_input: Vector2, fire_held: bool, ring: RingWorld, terrain: TerrainProfile, world_balance: Resource) -> Dictionary:
	invuln_timer = maxf(0.0, invuln_timer - delta)
	var max_h: float = balance.max_horizontal_speed

	# Horizontal: thrust with inertia; braking against existing velocity is
	# the fast phase so a full reversal totals balance.reversal_time (§4.2).
	if move_input.x != 0.0:
		facing = 1 if move_input.x > 0.0 else -1
		var accel: float = max_h / balance.time_to_max_speed
		if move_input.x * velocity.x < 0.0:
			accel = max_h / maxf(0.05, balance.reversal_time - balance.time_to_max_speed)
		velocity.x = move_toward(velocity.x, move_input.x * max_h, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, balance.release_decel * delta)

	# Vertical: direct control, slightly slower than horizontal (§4.2).
	velocity.y = move_input.y * balance.max_vertical_speed

	position += velocity * delta
	sim_x = ring.normalize_x(position.x)

	# Playable vertical band (§4.2). The clamp is the Cadet rebound; on
	# Pilot/Ace GameWorld turns touched_terrain into a lethal hit.
	var floor_y: float = terrain.get_surface_y(sim_x) - world_balance.terrain_clearance
	touched_terrain = position.y >= floor_y
	position.y = clampf(position.y, world_balance.min_player_y, floor_y)

	_visual.scale.x = float(facing)
	_visual.modulate.a = 0.45 if invuln_timer > 0.0 else 1.0

	# Arc Lance cadence (§4.3).
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if fire_held and _fire_cooldown == 0.0:
		_fire_cooldown = 1.0 / balance.fire_rate
		return {
			"sim_x": ring.normalize_x(sim_x + facing * balance.muzzle_offset),
			"y": position.y,
			"direction": facing,
		}
	return {}


## §4.4 step 1: control stops and the craft disappears for the respawn pause.
func begin_death(respawn_delay: float) -> void:
	alive = false
	visible = false
	velocity = Vector2.ZERO
	invuln_timer = 0.0
	touched_terrain = false
	_respawn_timer = respawn_delay


## Counts down the respawn pause while dead. Returns true once it elapses.
func tick_dead(delta: float) -> bool:
	_respawn_timer -= delta
	return _respawn_timer <= 0.0


## §4.4 step 5: back into play in place, at a safe altitude, invulnerable.
func respawn(invulnerability: float, altitude_y: float) -> void:
	alive = true
	visible = true
	velocity = Vector2.ZERO
	position.y = altitude_y
	invuln_timer = invulnerability
