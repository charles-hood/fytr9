## RunController (plan §10.2, §10.6): owns run-specific state — population,
## wave, score wiring, and run-end decisions — inside the session scene. Dies
## with the run; nothing here is global. Lives and bombs join in Milestone 3.
extends Node

const Settler := preload("res://scripts/actors/settler.gd")
const RngStreamsScript := preload("res://scripts/core/rng_streams.gd")
const SettlerCoordinatorScript := preload("res://scripts/core/settler_coordinator.gd")
const ScoreServiceScript := preload("res://scripts/core/score_service.gd")
const ThreatRegistryScript := preload("res://scripts/core/threat_registry.gd")
const WaveDirectorScript := preload("res://scripts/core/wave_director.gd")

signal run_ended(result: StringName, stats: Dictionary)

@export var wave_recipe: Resource  # WaveRecipe
@export var scoring_balance: Resource  # ScoringBalance
@export var settler_balance: Resource  # SettlerBalance

## 0 = derive a fresh seed from wall-clock entropy; tests set a fixed value.
@export var fixed_seed := 0

var run_seed := 0
var streams: RngStreams
var coordinator: SettlerCoordinator
var score_service: ScoreService
var registry: ThreatRegistry
var wave_director: WaveDirector
var run_over := false

@onready var _world: Node2D = %World
@onready var _hud: CanvasLayer = %HUD


func _ready() -> void:
	run_seed = fixed_seed if fixed_seed != 0 \
			else int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	streams = RngStreamsScript.new(run_seed)
	score_service = ScoreServiceScript.new(scoring_balance)
	registry = ThreatRegistryScript.new()
	coordinator = SettlerCoordinatorScript.new(
			_world.ring, settler_balance, wave_recipe.abduction_cap)
	wave_director = WaveDirectorScript.new(
			wave_recipe, streams.make_encounter_rng(wave_recipe.wave_number), _world.ring)

	score_service.score_changed.connect(_hud.set_score)
	_world.enemy_destroyed.connect(score_service.enemy_destroyed)
	coordinator.settler_taken.connect(_on_settler_taken)
	coordinator.settler_falling.connect(_on_settler_falling)
	coordinator.settler_caught.connect(_on_settler_caught)
	coordinator.settler_delivered.connect(_on_settler_delivered)
	coordinator.settler_lost.connect(_on_settler_lost)
	coordinator.settler_mutated.connect(_on_settler_mutated)

	_world.configure(self)
	_world.spawn_settlers(settler_balance.population)
	_hud.set_score(0)
	_hud.set_wave_label("WAVE %d" % wave_recipe.wave_number)
	_refresh_population()


## Called by GameWorld at the end of every physics tick (explicit pipeline).
func post_tick(_delta: float) -> void:
	_hud.update_scanner(registry, _world.camera_sim_x(), _world.ring.width)
	_hud.set_edge_warnings(_collect_edge_warnings())
	if run_over:
		return
	if coordinator.alive_count() == 0:
		_end_run(&"all_settlers_lost")
	elif wave_director.budget_exhausted() and _world.enemies.is_empty() \
			and not coordinator.has_unresolved_transitions():
		score_service.wave_cleared(wave_recipe.wave_number, coordinator.alive_count(),
				settler_balance.population)
		_end_run(&"wave_complete")


func _end_run(result: StringName) -> void:
	run_over = true
	_world.set_physics_process(false)
	run_ended.emit(result, {
		"score": score_service.total,
		"settlers": coordinator.alive_count(),
		"population": settler_balance.population,
		"seed": run_seed,
	})


## Directional screen-edge warnings (§4.5, §11) for off-screen abductions and
## falling Settlers: [{ side: -1|1, kind: StringName }].
func _collect_edge_warnings() -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	var cam_x: float = _world.camera_sim_x()
	for settler in coordinator.settlers:
		var kind: StringName
		match settler.state:
			Settler.State.CARRIED_BY_ENEMY:
				kind = &"abduction"
			Settler.State.FALLING:
				kind = &"falling"
			_:
				continue
		var delta: float = _world.ring.wrapped_delta_x(cam_x, settler.sim_x)
		if absf(delta) > 660.0:
			warnings.append({"side": signf(delta), "kind": kind})
	return warnings


func _refresh_population() -> void:
	_hud.set_population(coordinator.alive_count(), settler_balance.population)


func _on_settler_taken(_settler: Node2D) -> void:
	_hud.show_banner("SETTLER TAKEN!", Color("FF6600"))


func _on_settler_falling(_settler: Node2D) -> void:
	_hud.show_banner("SETTLER FALLING!", Color("FFFFCC"))


func _on_settler_caught(_settler: Node2D) -> void:
	score_service.settler_caught()
	_hud.show_banner("CAUGHT! +%d" % scoring_balance.catch_settler, Color("00FF88"))


func _on_settler_delivered(_settler: Node2D) -> void:
	score_service.settler_returned()
	_hud.show_banner("SETTLER RESCUED +%d" % scoring_balance.return_settler, Color("00FF88"))
	_refresh_population()


func _on_settler_lost(_settler: Node2D) -> void:
	_hud.show_banner("SETTLER LOST", Color("FF0000"))
	_refresh_population()


func _on_settler_mutated(_settler: Node2D) -> void:
	_hud.show_banner("SETTLER MUTATED", Color("FF0000"))
	_refresh_population()
