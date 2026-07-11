## Boot scene: hands off to AppState as soon as the tree is ready.
## Anything that must happen before the title screen (settings load, bus
## setup) is triggered from here in later milestones.
extends Node


func _ready() -> void:
	AppState.goto_title()
