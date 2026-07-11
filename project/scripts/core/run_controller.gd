## RunController (plan §10.2, §10.6): owns run-specific state — lives, bombs,
## wave progression through the §6.1 lifecycle, population, score wiring,
## reward thresholds, and run-end decisions — inside the session scene. Dies
## with the run; nothing here is global.
extends Node

const Settler := preload("res://scripts/actors/settler.gd")
const RngStreamsScript := preload("res://scripts/core/rng_streams.gd")
const SettlerCoordinatorScript := preload("res://scripts/core/settler_coordinator.gd")
const ScoreServiceScript := preload("res://scripts/core/score_service.gd")
const ThreatRegistryScript := preload("res://scripts/core/threat_registry.gd")
const WaveDirectorScript := preload("res://scripts/core/wave_director.gd")

signal run_ended(result: StringName, stats: Dictionary)

## §6.1 lifecycle for the current wave. The PLANET_COLLAPSE/extinction branch
## (§4.6) arrives in Milestone 4; in M3 losing the whole population ends the
## run (docs/DECISIONS.md).
enum Phase { PRE_WAVE, ACTIVE, CLEAR_PENDING, WAVE_COMPLETE }

@export var wave_table: Resource  # WaveTable
@export var scoring_balance: Resource  # ScoringBalance
@export var settler_balance: Resource  # SettlerBalance

## §6.4 presets, one per AppState.Difficulty value.
@export var cadet_preset: Resource  # DifficultyPreset
@export var pilot_preset: Resource
@export var ace_preset: Resource

## Tests force a difficulty index; -1 reads AppState (PILOT when the autoload
## is absent, e.g. headless test runs).
@export var forced_difficulty := -1

## 0 = derive a fresh seed from wall-clock entropy; tests set a fixed value.
@export var fixed_seed := 0

var run_seed := 0
var preset: Resource  # DifficultyPreset for this run
var streams: RngStreams
var coordinator: SettlerCoordinator
var score_service: ScoreService
var registry: ThreatRegistry
var wave_director: WaveDirector
var lives := 0
var bombs := 0
var wave_number := 0
var phase: Phase = Phase.PRE_WAVE
var run_over := false
var high_score := 0

var _phase_timer := 0.0
var _next_extra_ship := 0

@onready var _world: Node2D = %World
@onready var _hud: CanvasLayer = %HUD


func _ready() -> void:
	preset = _resolve_preset()
	run_seed = fixed_seed if fixed_seed != 0 \
			else int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	streams = RngStreamsScript.new(run_seed)
	score_service = ScoreServiceScript.new(scoring_balance)
	registry = ThreatRegistryScript.new()
	coordinator = SettlerCoordinatorScript.new(_world.ring, settler_balance, 1)
	lives = preset.lives
	bombs = preset.bombs
	_next_extra_ship = scoring_balance.extra_ship_first_score

	var save := get_node_or_null("/root/SaveService")
	high_score = save.best_score(preset.score_table) if save != null else 0

	score_service.score_changed.connect(_on_score_changed)
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
	_hud.set_high_score(high_score)
	_hud.set_lives(lives)
	_hud.set_bombs(bombs)
	_hud.set_difficulty(preset.display_name)
	_refresh_population()
	_enter_pre_wave(1)


## GameWorld pulls due spawn positions each tick; only ACTIVE waves spawn (§6.1).
func due_spawns(delta: float, active_snatchers: int, player_sim_x: float) -> Array[float]:
	if run_over or phase != Phase.ACTIVE:
		var none: Array[float] = []
		return none
	return wave_director.tick(delta, active_snatchers, player_sim_x)


## Called by GameWorld at the end of every physics tick (explicit pipeline).
## Death is reported synchronously DURING the tick, before this runs — so a
## simultaneous last-life death and wave clear resolves as game over (§6.1):
## run_over is already true here and the wave bonus is never awarded.
func post_tick(delta: float) -> void:
	_hud.update_scanner(registry, _world.camera_sim_x(), _world.ring.width)
	_hud.set_edge_warnings(_collect_edge_warnings())
	if run_over:
		return
	if coordinator.alive_count() == 0:
		# M3: losing the whole population ends the run; the §4.6
		# PLANET_COLLAPSE/extinction branch replaces this in Milestone 4.
		_end_run(&"all_settlers_lost")
		return
	match phase:
		Phase.PRE_WAVE:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				phase = Phase.ACTIVE
		Phase.ACTIVE:
			if wave_director.budget_exhausted():
				phase = Phase.CLEAR_PENDING
		Phase.CLEAR_PENDING:
			# §6.1: budget spent + no score-bearing enemies + no unresolved
			# Settler transition (a Settler in enemy or player hands, or
			# airborne, blocks completion).
			if _world.enemies.is_empty() and not coordinator.has_unresolved_transitions():
				score_service.wave_cleared(wave_number, coordinator.alive_count(),
						settler_balance.population)
				_hud.show_banner("WAVE %d CLEARED" % wave_number, Color("00FF88"))
				phase = Phase.WAVE_COMPLETE
				_phase_timer = wave_table.wave_complete_duration
		Phase.WAVE_COMPLETE:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				if wave_number >= wave_table.waves.size():
					# Waves 1-5 complete the M3 run; the post-5 endless curve
					# arrives in Milestone 4 (docs/DECISIONS.md).
					_end_run(&"run_complete")
				else:
					_enter_pre_wave(wave_number + 1)


## §4.4 death sequence. Steps happen in order: control stops (begin_death),
## carried Settlers resolve (released into FALLING — M3 decision mirroring
## the §4.3 failed-hyperspace rule), and the projectile/safety-radius
## clearing runs at respawn time in GameWorld. Setting run_over here, during
## the tick, is what makes game-over win simultaneous-event ties (§6.1).
func report_player_death(cause: StringName) -> void:
	if run_over or not _world.player.alive:
		return
	lives -= 1
	_hud.set_lives(lives)
	coordinator.release_player_carried()
	_world.player.begin_death(_world.player_balance.respawn_delay)
	if cause == &"hyperspace":
		_hud.show_banner("HYPERSPACE FAILURE", Color("FF00FF"))
	else:
		_hud.show_banner("SHIP DESTROYED", Color("FF0044"))
	if lives <= 0:
		_end_run(&"game_over")


## §4.3 Pulse Bomb: a run-level stock — never refilled on death; +1 per
## extra ship, capped at 5.
func request_pulse_bomb() -> void:
	if run_over or not _world.player.alive or bombs <= 0:
		return
	bombs -= 1
	_hud.set_bombs(bombs)
	_world.detonate_pulse_bomb()
	_hud.flash_screen()


## §4.3 hyperspace: the destination is selected — and unsafe candidates
## rejected — BEFORE the failure roll, never after. Both the destination
## draws and the roll come from gameplay_rng (§6.3), not encounter_rng.
func request_hyperspace() -> void:
	if run_over or not _world.player.alive:
		return
	var destination: Vector2 = _world.pick_hyperspace_destination(streams.gameplay)
	if streams.gameplay.randf() < preset.hyperspace_failure_chance:
		# Unique failure effect; a carried Settler starts falling at the
		# origin (§4.3) — the ship never left.
		report_player_death(&"hyperspace")
		return
	_world.teleport_player(destination)
	_world.player.invuln_timer = _world.player_balance.hyperspace_invulnerability


func _resolve_preset() -> Resource:
	var index := forced_difficulty
	if index < 0:
		var app_state := get_node_or_null("/root/AppState")
		index = app_state.difficulty if app_state != null else 1  # PILOT default
	return [cadet_preset, pilot_preset, ace_preset][clampi(index, 0, 2)]


func _enter_pre_wave(number: int) -> void:
	wave_number = number
	var recipe: Resource = wave_table.waves[number - 1]
	coordinator.abduction_cap = recipe.abduction_cap
	# Each wave's encounter schedule derives from (run_seed, wave_number)
	# alone (§6.3); WaveDirector owns the returned generator exclusively.
	wave_director = WaveDirectorScript.new(
			recipe, streams.make_encounter_rng(number), _world.ring)
	phase = Phase.PRE_WAVE
	_phase_timer = wave_table.pre_wave_duration
	_hud.set_wave_label("WAVE %d" % number)
	_hud.show_banner("WAVE %d" % number, Color("FFCC00"))


func _on_score_changed(total: int) -> void:
	_hud.set_score(total)
	if total > high_score:
		high_score = total
		_hud.set_high_score(high_score)
	# §4.4 extra ships: first at 10k, then every 50k. The §4.3 bomb rides
	# only on an actually awarded ship — a threshold crossed at the 5-ship
	# cap grants nothing and announces nothing (M3 review finding).
	while total >= _next_extra_ship:
		_next_extra_ship += scoring_balance.extra_ship_interval
		if lives >= scoring_balance.max_ships:
			continue
		lives += 1
		bombs = mini(bombs + 1, scoring_balance.max_bombs)
		_hud.set_lives(lives)
		_hud.set_bombs(bombs)
		_hud.show_banner("EXTRA SHIP", Color("00FF88"))


func _end_run(result: StringName) -> void:
	run_over = true
	_world.set_physics_process(false)
	var save := get_node_or_null("/root/SaveService")
	if save != null:
		save.record_score(preset.score_table, score_service.total)
	run_ended.emit(result, {
		"score": score_service.total,
		"high_score": high_score,
		"wave": wave_number,
		"settlers": coordinator.alive_count(),
		"population": settler_balance.population,
		"difficulty": preset.display_name,
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
