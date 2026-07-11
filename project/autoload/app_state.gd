## Application-level flow: boot/menu/run transitions, current difficulty,
## pause and retry flow (plan §10.2).
##
## Holds no run-specific state and no direct actor references — score, lives,
## wave, and the Settler roster belong to RunController inside the session
## scene (Milestone 3) and die with the run.
extends Node

enum Difficulty { CADET, PILOT, ACE }

const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const GAME_SESSION_SCENE := "res://scenes/game/game_session.tscn"

var difficulty: Difficulty = Difficulty.PILOT


func goto_title() -> void:
	_change_scene(TITLE_SCENE)


func start_run() -> void:
	_change_scene(GAME_SESSION_SCENE)


func _change_scene(path: String) -> void:
	# Deferred so scene changes are always safe to request from _ready,
	# input handlers, or physics callbacks.
	get_tree().change_scene_to_file.call_deferred(path)
