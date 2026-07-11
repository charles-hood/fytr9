## Singular gameplay-terrain height profile for the ring world (plan §10.3).
## Part of the simulation layer — NOT a Parallax2D presentation layer (§3, §16).
## Pure math, headless-testable; TerrainView renders it, entities query it.
##
## Built from sine components with integer cycle counts over the ring, so the
## profile is continuous (and smooth) across the seam by construction.
class_name TerrainProfile
extends RefCounted

var width: float
var base_y: float
# Each component: [cycles around the ring (int), amplitude px, phase rad].
var _components: Array = [
	[3, 40.0, 0.7],
	[7, 18.0, 2.1],
	[11, 8.0, 4.0],
]


func _init(p_width: float, p_base_y: float = 600.0) -> void:
	width = p_width
	base_y = p_base_y


## Surface height (scene y, +down) at any x, wrapped or not.
func get_surface_y(x: float) -> float:
	var n := fposmod(x, width)
	var y := base_y
	for c in _components:
		y += c[1] * sin(TAU * float(c[0]) * n / width + c[2])
	return y


## Lowest possible surface y value (highest peak), for spawn/band planning.
func min_surface_y() -> float:
	var total := 0.0
	for c in _components:
		total += c[1]
	return base_y - total
