## World controller: owns the RingWorld service, terrain profile, entity
## lists (settlers, enemies, shots, enemy shots), and the single explicit
## per-physics-frame update pipeline (deterministic ordering — no reliance on
## scene-tree _physics_process order). Run-level decisions live in
## RunController, which configures this world and receives post_tick() (§10.6):
## the world detects lethal contact and reports it; RunController decides what
## a death means (lives, carried Settlers, game over).
##
## Seam architecture (see docs/DECISIONS.md): every entity is one simulation
## object with a normalized ring position (sim_x). The player's node position
## is continuous/unwrapped and anchors the scene: each tick, every other
## entity is placed at player_scene_x + wrapped_delta_x(player.sim_x, sim_x).
## Scene-space geometry is therefore faithful everywhere within half a world
## of the player, so rendering and physics-adjacent checks cross the seam
## with no proxies, duplicates, or edge triggers (§10.3, §16). Terrain, the
## one object spanning the whole ring, is drawn windowed by TerrainView.
extends Node2D

const Settler := preload("res://scripts/actors/settler.gd")
const PLAYER_SHOT_SCENE := preload("res://scenes/actors/projectiles/player_shot.tscn")
const ENEMY_SHOT_SCENE := preload("res://scenes/actors/projectiles/enemy_shot.tscn")
const SETTLER_SCENE := preload("res://scenes/actors/settler.tscn")
const SNATCHER_SCENE := preload("res://scenes/actors/enemies/snatcher.tscn")

## Keep the anchor's continuous x bounded so 32-bit float precision never
## degrades on long runs; the same shift is applied to player and camera in
## the same tick, so the rebase is invisible.
const REBASE_LAPS := 16.0

## Half the 1280px logical viewport; the Pulse Bomb reach and edge warnings
## are defined relative to it (§4.3, §11).
const VIEWPORT_HALF_WIDTH := 640.0

signal enemy_destroyed(entity_id: int, kind: StringName)

@export var world_balance: Resource  # WorldBalance
@export var player_balance: Resource  # PlayerBalance
@export var settler_balance: Resource  # SettlerBalance
@export var snatcher_balance: Resource  # SnatcherBalance

var ring: RingWorld
var terrain: TerrainProfile
var settlers: Array = []
var enemies: Array = []
var shots: Array = []
var enemy_shots: Array = []

var run: Node = null  # RunController; set via configure()

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $GameCamera
@onready var terrain_view: Node2D = $Terrain
@onready var debug_overlay: CanvasLayer = $DebugOverlay


func _ready() -> void:
	ring = RingWorld.new(world_balance.world_width)
	terrain = TerrainProfile.new(world_balance.world_width)
	terrain_view.setup(ring, terrain)
	debug_overlay.world = self
	player.position = Vector2(640.0, 360.0)
	player.sim_x = ring.normalize_x(player.position.x)


func configure(p_run: Node) -> void:
	run = p_run


func camera_sim_x() -> float:
	return ring.normalize_x(camera.position.x)


func spawn_settlers(count: int) -> void:
	# Spread evenly with gameplay-rng jitter; positions are not part of the
	# authored encounter schedule (§6.3).
	for i in count:
		var settler := SETTLER_SCENE.instantiate()
		var jitter: float = run.streams.gameplay.randf_range(-120.0, 120.0)
		var x := ring.normalize_x((i + 0.5) / count * ring.width + jitter)
		add_child(settler)
		settler.setup(x, settler_balance, terrain)
		run.coordinator.register_settler(settler)
		settlers.append(settler)


func spawn_snatcher(p_sim_x: float) -> void:
	var snatcher := SNATCHER_SCENE.instantiate()
	add_child(snatcher)
	var y: float = run.streams.gameplay.randf_range(
			snatcher_balance.patrol_y_min, snatcher_balance.patrol_y_max)
	snatcher.setup(p_sim_x, y, snatcher_balance, run.coordinator,
			run.preset.enemy_speed_scale)
	snatcher.died.connect(_on_enemy_died)
	snatcher.escaped.connect(_on_enemy_exited)
	enemies.append(snatcher)


func spawn_player_shot(p_sim_x: float, p_y: float, p_direction: int) -> void:
	var shot := PLAYER_SHOT_SCENE.instantiate()
	shot.setup(p_sim_x, p_y, p_direction, player_balance)
	add_child(shot)
	shots.append(shot)


func spawn_enemy_shot(volley: Dictionary) -> void:
	var shot := ENEMY_SHOT_SCENE.instantiate()
	shot.setup(volley["sim_x"], volley["y"], volley["velocity"],
			snatcher_balance.shot_lifetime)
	add_child(shot)
	enemy_shots.append(shot)


func _physics_process(delta: float) -> void:
	if run == null:
		return
	if player.alive:
		var move_input := Vector2(
				Input.get_axis("move_left", "move_right"),
				Input.get_axis("move_up", "move_down"))
		var fire_request: Dictionary = player.tick(
				delta, move_input, Input.is_action_pressed("fire"), ring, terrain, world_balance)
		if not fire_request.is_empty():
			spawn_player_shot(fire_request["sim_x"], fire_request["y"], fire_request["direction"])
		if run.preset.lethal_terrain and player.touched_terrain and player.invuln_timer <= 0.0:
			run.report_player_death(&"terrain")
		if Input.is_action_just_pressed("pulse_bomb"):
			run.request_pulse_bomb()
		if Input.is_action_just_pressed("hyperspace"):
			run.request_hyperspace()
	elif player.tick_dead(delta) and not run.run_over:
		_respawn_player()

	for x in run.due_spawns(delta, enemies.size(), player.sim_x):
		spawn_snatcher(x)

	# Enemies may remove themselves (escape) via signals during iteration.
	var aim_target: Node2D = player if player.alive else null
	for enemy in enemies.duplicate():
		var volley: Dictionary = enemy.tick(delta, ring, run.streams.gameplay, aim_target)
		if not volley.is_empty():
			spawn_enemy_shot(volley)

	_check_player_enemy_contact()

	for settler in settlers:
		settler.tick(delta, ring, terrain, run.streams.gameplay)

	for i in range(shots.size() - 1, -1, -1):
		var shot: Area2D = shots[i]
		if not shot.tick(delta, ring, terrain, enemies):
			shots.remove_at(i)
			shot.queue_free()

	_tick_enemy_shots(delta)
	_handle_rescue()
	run.registry.rebuild(player, enemies, settlers)
	_place_entities()
	camera.tick(delta, player)
	_maybe_rebase()
	run.post_tick(delta)


## §4.3 Pulse Bomb: kills enemies and hostile projectiles in the visible
## viewport plus a wrapped seam margin. Settlers are unharmed — a carried
## Settler drops because its carrier dies (the §4.5 falling rule), not from
## bomb damage.
func detonate_pulse_bomb() -> void:
	var cam_x := camera_sim_x()
	var reach: float = VIEWPORT_HALF_WIDTH + player_balance.bomb_seam_margin
	for enemy in enemies.duplicate():
		if enemy.alive and ring.wrapped_distance_x(cam_x, enemy.sim_x) <= reach:
			enemy.take_hit()
	for i in range(enemy_shots.size() - 1, -1, -1):
		if ring.wrapped_distance_x(cam_x, enemy_shots[i].sim_x) <= reach:
			var shot: Area2D = enemy_shots[i]
			enemy_shots.remove_at(i)
			shot.queue_free()


## §4.3 hyperspace destination: candidates are drawn from gameplay_rng and
## REJECTED while unsafe — below the clearance band above the highest terrain
## peak or too close to a hostile — before the failure roll ever happens
## (RunController rolls only against the destination this returns). If no
## candidate clears every hostile, the least-crowded one is used: arriving
## pressured is acceptable, arriving inside a hull is not.
func pick_hyperspace_destination(rng: RandomNumberGenerator) -> Vector2:
	var y_min: float = world_balance.min_player_y
	var y_max: float = terrain.min_surface_y() - player_balance.hyperspace_terrain_clearance
	var best := Vector2(player.sim_x, player_balance.respawn_y)
	var best_clearance := -INF
	for attempt in 32:
		var candidate := Vector2(rng.randf_range(0.0, ring.width), rng.randf_range(y_min, y_max))
		var clearance := _hostile_clearance(candidate)
		if clearance >= player_balance.hyperspace_min_clearance:
			return candidate
		if clearance > best_clearance:
			best_clearance = clearance
			best = candidate
	return best


## Wrapped distance from a point to the nearest hostile (enemy or shot).
func _hostile_clearance(point: Vector2) -> float:
	var nearest := INF
	for group in [enemies, enemy_shots]:
		for hostile in group:
			var dx: float = ring.wrapped_delta_x(point.x, hostile.sim_x)
			var dy: float = hostile.sim_y - point.y
			nearest = minf(nearest, Vector2(dx, dy).length())
	return nearest


func teleport_player(destination: Vector2) -> void:
	player.position.x += ring.wrapped_delta_x(player.sim_x, destination.x)
	player.position.y = destination.y
	player.sim_x = ring.normalize_x(player.position.x)


## Player-side Settler interactions (§4.5): catch falling Settlers by
## overlap; carried Settlers hang below the craft (stacking if several) and
## return to the surface inside the safe drop band.
func _handle_rescue() -> void:
	if not player.alive:
		return
	var catch_radius: float = settler_balance.catch_radius * run.preset.catch_radius_scale
	var carry_index := 0
	for settler in settlers:
		match settler.state:
			Settler.State.FALLING:
				if ring.wrapped_distance_x(player.sim_x, settler.sim_x) <= catch_radius \
						and absf(player.position.y - settler.sim_y) <= catch_radius:
					run.coordinator.catch_settler(settler)
			Settler.State.CARRIED_BY_PLAYER:
				settler.sim_x = player.sim_x
				settler.sim_y = player.position.y + settler_balance.carry_offset_y \
						+ carry_index * settler_balance.carry_stack_spacing
				carry_index += 1
				var ground_y: float = terrain.get_surface_y(settler.sim_x) - settler_balance.ground_offset
				if ground_y - settler.sim_y <= settler_balance.drop_band_height:
					run.coordinator.deliver_settler(settler, ground_y)


## Ramming (M3 decision, docs/DECISIONS.md): colliding with an enemy destroys
## both — the enemy dies and scores normally; the ship is lost.
func _check_player_enemy_contact() -> void:
	if not player.alive or player.invuln_timer > 0.0:
		return
	for enemy in enemies.duplicate():
		if not enemy.alive:
			continue
		var dx: float = ring.wrapped_delta_x(player.sim_x, enemy.sim_x)
		var dy: float = enemy.sim_y - player.position.y
		var reach: float = enemy.hit_radius + player_balance.hit_radius
		if dx * dx + dy * dy <= reach * reach:
			enemy.take_hit()
			run.report_player_death(&"collision")
			return


func _tick_enemy_shots(delta: float) -> void:
	for i in range(enemy_shots.size() - 1, -1, -1):
		var shot: Area2D = enemy_shots[i]
		var live: bool = shot.tick(delta, ring, terrain)
		if live and player.alive and player.invuln_timer <= 0.0:
			var dx: float = ring.wrapped_delta_x(player.sim_x, shot.sim_x)
			var dy: float = shot.sim_y - player.position.y
			var reach: float = shot.hit_radius + player_balance.hit_radius
			if dx * dx + dy * dy <= reach * reach:
				run.report_player_death(&"enemy_fire")
				live = false
		if not live:
			enemy_shots.remove_at(i)
			shot.queue_free()


## §4.4 steps 4-5: clear hostile projectiles inside the safety radius, push
## enemies to its edge, then respawn in place at a safe altitude with brief
## invulnerability.
func _respawn_player() -> void:
	var radius: float = player_balance.respawn_safety_radius
	for i in range(enemy_shots.size() - 1, -1, -1):
		if ring.wrapped_distance_x(player.sim_x, enemy_shots[i].sim_x) <= radius:
			var shot: Area2D = enemy_shots[i]
			enemy_shots.remove_at(i)
			shot.queue_free()
	for enemy in enemies:
		var dx: float = ring.wrapped_delta_x(player.sim_x, enemy.sim_x)
		if absf(dx) < radius:
			var side := 1.0 if dx >= 0.0 else -1.0
			enemy.sim_x = ring.normalize_x(player.sim_x + side * radius)
	player.respawn(player_balance.respawn_invulnerability, player_balance.respawn_y)


func _on_enemy_died(enemy: Area2D) -> void:
	enemies.erase(enemy)
	enemy_destroyed.emit(enemy.get_instance_id(), &"snatcher")
	enemy.queue_free()


func _on_enemy_exited(enemy: Area2D) -> void:
	# Escaped with a Settler: no score, no destruction event (§4.5). The
	# Ravager it becomes arrives with the Milestone 4 roster.
	enemies.erase(enemy)
	enemy.queue_free()


func _place_entities() -> void:
	var anchor_x: float = player.position.x
	var anchor_sim_x: float = player.sim_x
	for group in [settlers, enemies, shots, enemy_shots]:
		for entity in group:
			entity.position = Vector2(
					anchor_x + ring.wrapped_delta_x(anchor_sim_x, entity.sim_x), entity.sim_y)


func _maybe_rebase() -> void:
	if absf(player.position.x) > REBASE_LAPS * ring.width:
		var shift := -roundf(player.position.x / ring.width) * ring.width
		player.position.x += shift
		camera.apply_rebase(shift)
