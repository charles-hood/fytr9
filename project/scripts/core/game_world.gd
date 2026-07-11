## World controller: owns the RingWorld service, terrain profile, entity
## lists (settlers, enemies, shots), and the single explicit per-physics-
## frame update pipeline (deterministic ordering — no reliance on scene-tree
## _physics_process order). Run-level decisions live in RunController, which
## configures this world and receives post_tick() (§10.6).
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
const SETTLER_SCENE := preload("res://scenes/actors/settler.tscn")
const SNATCHER_SCENE := preload("res://scenes/actors/enemies/snatcher.tscn")

## Keep the anchor's continuous x bounded so 32-bit float precision never
## degrades on long runs; the same shift is applied to player and camera in
## the same tick, so the rebase is invisible.
const REBASE_LAPS := 16.0

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
	snatcher.setup(p_sim_x, y, snatcher_balance, run.coordinator)
	snatcher.died.connect(_on_enemy_died)
	snatcher.escaped.connect(_on_enemy_exited)
	enemies.append(snatcher)


func spawn_player_shot(p_sim_x: float, p_y: float, p_direction: int) -> void:
	var shot := PLAYER_SHOT_SCENE.instantiate()
	shot.setup(p_sim_x, p_y, p_direction, player_balance)
	add_child(shot)
	shots.append(shot)


func _physics_process(delta: float) -> void:
	if run == null:
		return
	var move_input := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down"))
	var fire_request: Dictionary = player.tick(
			delta, move_input, Input.is_action_pressed("fire"), ring, terrain, world_balance)
	if not fire_request.is_empty():
		spawn_player_shot(fire_request["sim_x"], fire_request["y"], fire_request["direction"])

	for x in run.wave_director.tick(delta, enemies.size(), player.sim_x):
		spawn_snatcher(x)

	# Enemies may remove themselves (escape) via signals during iteration.
	for enemy in enemies.duplicate():
		enemy.tick(delta, ring, run.streams.gameplay)

	for settler in settlers:
		settler.tick(delta, ring, terrain, run.streams.gameplay)

	for i in range(shots.size() - 1, -1, -1):
		var shot: Area2D = shots[i]
		if not shot.tick(delta, ring, terrain, enemies):
			shots.remove_at(i)
			shot.queue_free()

	_handle_rescue()
	run.registry.rebuild(player, enemies, settlers)
	_place_entities()
	camera.tick(delta, player)
	_maybe_rebase()
	run.post_tick(delta)


## Player-side Settler interactions (§4.5): catch falling Settlers by
## overlap; carried Settlers hang below the craft (stacking if several) and
## return to the surface inside the safe drop band.
func _handle_rescue() -> void:
	var carry_index := 0
	for settler in settlers:
		match settler.state:
			Settler.State.FALLING:
				if ring.wrapped_distance_x(player.sim_x, settler.sim_x) <= settler_balance.catch_radius \
						and absf(player.position.y - settler.sim_y) <= settler_balance.catch_radius:
					run.coordinator.catch_settler(settler)
			Settler.State.CARRIED_BY_PLAYER:
				settler.sim_x = player.sim_x
				settler.sim_y = player.position.y + settler_balance.carry_offset_y \
						+ carry_index * settler_balance.carry_stack_spacing
				carry_index += 1
				var ground_y: float = terrain.get_surface_y(settler.sim_x) - settler_balance.ground_offset
				if ground_y - settler.sim_y <= settler_balance.drop_band_height:
					run.coordinator.deliver_settler(settler, ground_y)


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
	for group in [settlers, enemies, shots]:
		for entity in group:
			entity.position = Vector2(
					anchor_x + ring.wrapped_delta_x(anchor_sim_x, entity.sim_x), entity.sim_y)


func _maybe_rebase() -> void:
	if absf(player.position.x) > REBASE_LAPS * ring.width:
		var shift := -roundf(player.position.x / ring.width) * ring.width
		player.position.x += shift
		camera.apply_rebase(shift)
