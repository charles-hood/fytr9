## Session root: wires RunController's run-end into the overlay and handles
## the retry/quit input. Pause here is still a temporary return-to-title
## until the real pause flow exists (Milestone 3).
extends Node2D

@onready var _run: Node = %RunController
@onready var _overlay: CanvasLayer = %RunEndOverlay
@onready var _result_label: Label = %ResultLabel
@onready var _stats_label: Label = %StatsLabel


func _ready() -> void:
	_overlay.visible = false
	_run.run_ended.connect(_on_run_ended)


func _unhandled_input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed("fire"):
		AppState.start_run()  # instant retry: fresh session scene
	elif event.is_action_pressed("pause"):
		AppState.goto_title()


func _on_run_ended(result: StringName, stats: Dictionary) -> void:
	if result == &"wave_complete":
		_result_label.text = "WAVE COMPLETE"
		_result_label.add_theme_color_override("font_color", Color("00FF88"))
	else:
		_result_label.text = "ALL SETTLERS LOST"
		_result_label.add_theme_color_override("font_color", Color("FF0000"))
	_stats_label.text = "SCORE %d   —   SETTLERS %d/%d   —   SEED %d\nFIRE TO RETRY  ·  ESC FOR TITLE" % [
			stats["score"], stats["settlers"], stats["population"], stats["seed"]]
	_overlay.visible = true
