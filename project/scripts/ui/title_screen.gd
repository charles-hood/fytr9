## Placeholder title screen with difficulty selection (§6.4). The real menu
## flow — how-to-play, options, high scores, credits — arrives in Milestone 5.
extends Control

@onready var _difficulty_label: Label = %DifficultyLabel


func _ready() -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		AppState.start_run()
	elif event.is_action_pressed("move_left"):
		AppState.cycle_difficulty(-1)
		_refresh()
	elif event.is_action_pressed("move_right"):
		AppState.cycle_difficulty(1)
		_refresh()


func _refresh() -> void:
	_difficulty_label.text = "<  %s  >" % AppState.difficulty_name()
