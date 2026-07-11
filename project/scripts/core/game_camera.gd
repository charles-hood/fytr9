## Follows the player with modest velocity-scaled look-ahead in the
## facing/velocity direction (plan §4.1, §4.2). Vertical is fixed: the world
## fits the 720px logical height exactly.
extends Camera2D

@export var balance: Resource  # PlayerBalance

var _lookahead := 0.0


func _ready() -> void:
	make_current()
	position = Vector2(640.0, 360.0)


func tick(delta: float, player: CharacterBody2D) -> void:
	var target: float = balance.camera_lookahead_fraction * 1280.0 \
			* clampf(player.velocity.x / balance.max_horizontal_speed, -1.0, 1.0)
	_lookahead = lerpf(_lookahead, target,
			1.0 - exp(-balance.camera_lookahead_response * delta))
	position.x = player.position.x + _lookahead
	position.y = 360.0


## Same-tick shift applied when GameWorld rebases the anchor (invisible).
func apply_rebase(shift: float) -> void:
	position.x += shift
