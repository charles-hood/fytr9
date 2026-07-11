## Arc Lance projectile (plan §4.3, §10.4). Area2D with fixed-step manual
## motion; hits are resolved by a swept wrapped-math check (the "equivalent
## swept check" §4.3 allows), so a shot can never tunnel through a target or
## miss across the seam. One simulation object; GameWorld places the node in
## anchored scene space each tick.
extends Area2D

var sim_x := 0.0
var sim_y := 0.0
var direction := 1
var speed := 800.0
var life := 1.1


func setup(p_sim_x: float, p_sim_y: float, p_direction: int, p_balance: Resource) -> void:
	sim_x = p_sim_x
	sim_y = p_sim_y
	direction = p_direction
	speed = p_balance.projectile_speed
	life = p_balance.projectile_lifetime


## Advance one fixed step. Returns false when the shot is spent (expired,
## terrain impact, or target hit). targets entries need: alive, sim_x, sim_y,
## hit_radius, take_hit().
func tick(delta: float, ring: RingWorld, terrain: TerrainProfile, targets: Array) -> bool:
	life -= delta
	if life <= 0.0:
		return false

	var start_x := sim_x
	var travel := float(direction) * speed * delta
	sim_x = ring.normalize_x(sim_x + travel)

	if sim_y >= terrain.get_surface_y(sim_x):
		return false

	for target in targets:
		if not target.alive:
			continue
		if absf(target.sim_y - sim_y) > target.hit_radius:
			continue
		# Distance ahead of the shot's start position along its flight
		# direction, via the shortest wrapped route.
		var along: float = ring.wrapped_delta_x(start_x, target.sim_x) * float(direction)
		if along >= -target.hit_radius and along <= absf(travel) + target.hit_radius:
			target.take_hit()
			return false
	return true
