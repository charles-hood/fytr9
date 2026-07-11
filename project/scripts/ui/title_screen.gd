## Placeholder title screen (Milestone 0). The real menu flow — how-to-play,
## options, high scores, credits — arrives in Milestone 5.
extends Control


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		AppState.start_run()
