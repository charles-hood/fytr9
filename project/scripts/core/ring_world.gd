## Centralized wrapped-world math (plan §10.3). Every system that needs
## targeting, camera-relative rendering, scanner mapping, spawn selection, or
## abduction seeking calls this service — never ad-hoc modulo or
## `WORLD_WIDTH - position.x` arithmetic (§16).
##
## Pure math over a ring of `width` logical pixels; no scene access.
class_name RingWorld
extends RefCounted

var width: float


func _init(p_width: float) -> void:
	assert(p_width > 0.0, "ring width must be positive")
	width = p_width


## Returns x mapped into [0, width), for any input including negative and
## multi-wrap values.
func normalize_x(x: float) -> float:
	return fposmod(x, width)


## Shortest signed displacement from from_x to to_x, in [-width/2, width/2).
## The exact half-world tie resolves to -width/2 (the negative direction),
## deterministically (§10.3 requires the tie case be defined and tested).
func wrapped_delta_x(from_x: float, to_x: float) -> float:
	return fposmod(to_x - from_x + width * 0.5, width) - width * 0.5


## Shortest absolute distance between two ring positions, in [0, width/2].
func wrapped_distance_x(from_x: float, to_x: float) -> float:
	return absf(wrapped_delta_x(from_x, to_x))


## Where world_x sits relative to a camera at camera_x, using the shortest
## route around the ring.
func camera_relative_x(world_x: float, camera_x: float) -> float:
	return wrapped_delta_x(camera_x, world_x)
