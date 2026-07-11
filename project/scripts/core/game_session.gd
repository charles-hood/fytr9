## Placeholder game session root (Milestone 0). RunController, the ring world,
## and the player arrive in Milestones 1-3. Pause here is a temporary
## return-to-title until the real pause flow exists (Milestone 3).
extends Node2D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		AppState.goto_title()
