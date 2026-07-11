## Milestone 1 flight-lab target dummy. Scaffolding only — replaced by the
## real enemy roster from Milestone 2 on. Respawns after a short delay so the
## lab stays target-rich.
extends Area2D

const RESPAWN_DELAY := 2.0

var sim_x := 0.0
var sim_y := 0.0
var hit_radius := 18.0
var alive := true

var _respawn_timer := 0.0


func setup(p_sim_x: float, p_sim_y: float) -> void:
	sim_x = p_sim_x
	sim_y = p_sim_y


func take_hit() -> void:
	alive = false
	visible = false
	_respawn_timer = RESPAWN_DELAY


func tick(delta: float) -> void:
	if alive:
		return
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		alive = true
		visible = true
