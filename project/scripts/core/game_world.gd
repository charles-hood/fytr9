## Milestone 1 world controller: owns the RingWorld service, the terrain
## profile, the flight-lab dummies, active shots, and the single explicit
## per-physics-frame update pipeline (deterministic ordering — no reliance on
## scene-tree _physics_process order).
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

const PLAYER_SHOT_SCENE := preload("res://scenes/actors/projectiles/player_shot.tscn")
const DUMMY_SCENE := preload("res://scenes/actors/target_dummy.tscn")

## Flight-lab dummy positions (fractions of world width, scene y). Includes
## the exact seam (0.0) and both near-seam sides on purpose. M1 scaffolding,
## not balance data — the real roster replaces these in M2.
const DUMMY_SPOTS: Array = [
	[0.0, 300.0],
	[0.0105, 200.0],  # ~x=40
	[0.9895, 420.0],  # ~x=-40
	[0.15, 350.0],
	[0.3, 180.0],
	[0.45, 460.0],
	[0.6, 250.0],
	[0.75, 380.0],
	[0.9, 160.0],
]

## Keep the anchor's continuous x bounded so 32-bit float precision never
## degrades on long runs; the same shift is applied to player and camera in
## the same tick, so the rebase is invisible.
const REBASE_LAPS := 16.0

@export var world_balance: Resource  # WorldBalance
@export var player_balance: Resource  # PlayerBalance

var ring: RingWorld
var terrain: TerrainProfile
var targets: Array = []
var shots: Array = []

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
	for spot in DUMMY_SPOTS:
		var dummy := DUMMY_SCENE.instantiate()
		dummy.setup(ring.normalize_x(spot[0] * ring.width), spot[1])
		add_child(dummy)
		targets.append(dummy)
	_place_entities()


func _physics_process(delta: float) -> void:
	var move_input := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_up", "move_down"))
	var fire_request: Dictionary = player.tick(
			delta, move_input, Input.is_action_pressed("fire"), ring, terrain, world_balance)
	if not fire_request.is_empty():
		spawn_player_shot(fire_request["sim_x"], fire_request["y"], fire_request["direction"])

	for i in range(shots.size() - 1, -1, -1):
		var shot: Area2D = shots[i]
		if not shot.tick(delta, ring, terrain, targets):
			shots.remove_at(i)
			shot.queue_free()

	for dummy in targets:
		dummy.tick(delta)

	_place_entities()
	camera.tick(delta, player)
	_maybe_rebase()


func spawn_player_shot(p_sim_x: float, p_y: float, p_direction: int) -> void:
	var shot := PLAYER_SHOT_SCENE.instantiate()
	shot.setup(p_sim_x, p_y, p_direction, player_balance)
	add_child(shot)
	shots.append(shot)


func _place_entities() -> void:
	var anchor_x: float = player.position.x
	var anchor_sim_x: float = player.sim_x
	for dummy in targets:
		dummy.position = Vector2(
				anchor_x + ring.wrapped_delta_x(anchor_sim_x, dummy.sim_x), dummy.sim_y)
	for shot in shots:
		shot.position = Vector2(
				anchor_x + ring.wrapped_delta_x(anchor_sim_x, shot.sim_x), shot.sim_y)


func _maybe_rebase() -> void:
	if absf(player.position.x) > REBASE_LAPS * ring.width:
		var shift := -roundf(player.position.x / ring.width) * ring.width
		player.position.x += shift
		camera.apply_rebase(shift)
