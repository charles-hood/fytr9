## Milestone 1 debug overlay (plan M1 task list): logical/normalized X,
## wrapped delta, velocity, FPS. Toggle with F3. Dev scaffolding only.
extends CanvasLayer

var world: Node2D

@onready var _label: Label = $Label


func _ready() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F3:
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or world == null:
		return
	var player: CharacterBody2D = world.player
	var ring: RingWorld = world.ring
	var nearest_delta := INF
	for enemy in world.enemies:
		if enemy.alive:
			var d: float = ring.wrapped_delta_x(player.sim_x, enemy.sim_x)
			if absf(d) < absf(nearest_delta):
				nearest_delta = d
	_label.text = "\n".join([
		"FPS %d" % Engine.get_frames_per_second(),
		"scene x (unwrapped) %.1f" % player.position.x,
		"sim x (normalized)  %.1f / %.0f" % [player.sim_x, ring.width],
		"velocity (%.0f, %.0f)  facing %d" % [player.velocity.x, player.velocity.y, player.facing],
		"camera x %.1f" % world.camera.position.x,
		"nearest enemy delta %.1f" % nearest_delta,
		"shots %d  enemies %d  settlers alive %d" % [world.shots.size(), world.enemies.size(),
				world.settlers.filter(func(s): return s.is_alive()).size()],
	])
