## Verifies every Milestone 0 scene parses and instantiates headlessly.
## instantiate() does not trigger _ready, so no autoload access happens here.
extends "res://tests/test_case.gd"

const SCENES: Array[String] = [
	"res://scenes/boot/boot.tscn",
	"res://scenes/menus/title_screen.tscn",
	"res://scenes/game/game_session.tscn",
	"res://scenes/game/hud.tscn",
	"res://scenes/game/scanner.tscn",
	"res://scenes/actors/settler.tscn",
	"res://scenes/actors/enemies/snatcher.tscn",
]


func test_scenes_load_and_instantiate() -> void:
	for path in SCENES:
		var packed: PackedScene = load(path)
		assert_true(packed != null, path + " loads")
		if packed == null:
			continue
		var instance := packed.instantiate()
		assert_true(instance != null, path + " instantiates")
		if instance != null:
			instance.free()


func test_autoload_scripts_parse() -> void:
	for path in [
		"res://autoload/app_state.gd",
		"res://autoload/save_service.gd",
		"res://autoload/audio_director.gd",
	]:
		var script: GDScript = load(path)
		assert_true(script != null and script.can_instantiate(), path + " parses")
