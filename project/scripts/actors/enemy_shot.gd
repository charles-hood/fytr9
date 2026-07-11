## Hostile aimed projectile (plan §5, §10.4). Area2D with fixed-step manual
## motion — one simulation object placed in anchored scene space by GameWorld.
## Velocity is fixed at fire time (aimed shots fly straight); the shot dies on
## terrain, above the playfield, or by lifetime. The player hit check lives in
## GameWorld, which owns the invulnerability rules.
extends Area2D

var sim_x := 0.0
var sim_y := 0.0
var velocity := Vector2.ZERO
var life := 3.5
var hit_radius := 5.0


func setup(p_sim_x: float, p_sim_y: float, p_velocity: Vector2, p_lifetime: float) -> void:
	sim_x = p_sim_x
	sim_y = p_sim_y
	velocity = p_velocity
	life = p_lifetime


## Advance one fixed step. Returns false when the shot is spent.
func tick(delta: float, ring: RingWorld, terrain: TerrainProfile) -> bool:
	life -= delta
	if life <= 0.0:
		return false
	sim_x = ring.normalize_x(sim_x + velocity.x * delta)
	sim_y += velocity.y * delta
	if sim_y < -20.0 or sim_y >= terrain.get_surface_y(sim_x):
		return false
	return true
