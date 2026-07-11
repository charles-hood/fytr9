## Session root: pause overlay, run-end overlay, and the instant-retry flow
## (§13 M3 exit criterion: boot -> game over -> instant retry). The root node
## is PROCESS_MODE_ALWAYS so it still receives input while the tree is
## paused; World and HUD are PROCESS_MODE_PAUSABLE (set in the scene) so the
## simulation and HUD timers actually stop.
extends Node2D

@onready var _run: Node = %RunController
@onready var _overlay: CanvasLayer = %RunEndOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _pause_overlay: CanvasLayer = %PauseOverlay


func _ready() -> void:
	_overlay.visible = false
	_pause_overlay.visible = false
	_run.run_ended.connect(_on_run_ended)


func _exit_tree() -> void:
	# Never leave the whole tree paused behind a scene change.
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible:
		if event.is_action_pressed("fire"):
			AppState.start_run()  # instant retry: fresh session scene
		elif event.is_action_pressed("pause"):
			AppState.goto_title()
		return
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif get_tree().paused and event.is_action_pressed("hyperspace"):
		# Q/L doubles as "quit to title" on the pause screen.
		_set_paused(false)
		AppState.goto_title()


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_overlay.visible = paused


func _on_run_ended(result: StringName, stats: Dictionary) -> void:
	match result:
		&"run_complete":
			_result_label.text = "SECTOR CLEARED"
			_result_label.add_theme_color_override("font_color", Color("00FF88"))
		&"all_settlers_lost":
			_result_label.text = "ALL SETTLERS LOST"
			_result_label.add_theme_color_override("font_color", Color("FF0000"))
		_:
			_result_label.text = "GAME OVER"
			_result_label.add_theme_color_override("font_color", Color("FF0000"))
	_stats_label.text = "SCORE %d  ·  HI %d  ·  WAVE %d  ·  SETTLERS %d/%d\n%s  ·  SEED %d\nFIRE TO RETRY  ·  ESC FOR TITLE" % [
			stats["score"], stats["high_score"], stats["wave"], stats["settlers"],
			stats["population"], stats["difficulty"], stats["seed"]]
	_overlay.visible = true
