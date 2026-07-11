## Application-level flow: boot/menu/run transitions and the current
## difficulty selection (plan §10.2).
##
## Holds no run-specific state and no direct actor references — score, lives,
## bombs, wave, and the Settler roster belong to RunController inside the
## session scene and die with the run.
extends Node

enum Difficulty { CADET, PILOT, ACE }

const DIFFICULTY_NAMES: Array[String] = ["CADET", "PILOT", "ACE"]

const TITLE_SCENE := "res://scenes/menus/title_screen.tscn"
const GAME_SESSION_SCENE := "res://scenes/game/game_session.tscn"

var difficulty: Difficulty = Difficulty.PILOT


func goto_title() -> void:
	_change_scene(TITLE_SCENE)


func start_run() -> void:
	_change_scene(GAME_SESSION_SCENE)


func cycle_difficulty(step: int) -> void:
	difficulty = ((difficulty + step + DIFFICULTY_NAMES.size())
			% DIFFICULTY_NAMES.size()) as Difficulty


func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]


func _change_scene(path: String) -> void:
	# Deferred so scene changes are always safe to request from _ready,
	# input handlers, or physics callbacks.
	get_tree().change_scene_to_file.call_deferred(path)
