## Renders the TerrainProfile as a filled ridge across the visible window
## (plus margin), sampling the wrapped profile directly — so the seam is
## continuous by construction and no seam proxy geometry is needed. Pure
## presentation: simulation queries go to TerrainProfile (§10.3).
extends Node2D

const SAMPLE_STEP := 8.0
const MARGIN := 64.0
const FILL_BOTTOM := 760.0
const FILL_COLOR := Color("885522")
const RIDGE_COLOR := Color("b06a2e")

var _ring: RingWorld
var _profile: TerrainProfile


func setup(ring: RingWorld, profile: TerrainProfile) -> void:
	_ring = ring
	_profile = profile
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _profile == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var half_view := 640.0 + MARGIN
	var left := camera.position.x - half_view
	var right := camera.position.x + half_view

	var ridge := PackedVector2Array()
	var x := left
	while x <= right + SAMPLE_STEP:
		ridge.append(Vector2(x, _profile.get_surface_y(_ring.normalize_x(x))))
		x += SAMPLE_STEP

	var fill := ridge.duplicate()
	fill.append(Vector2(ridge[ridge.size() - 1].x, FILL_BOTTOM))
	fill.append(Vector2(ridge[0].x, FILL_BOTTOM))
	draw_colored_polygon(fill, FILL_COLOR)
	draw_polyline(ridge, RIDGE_COLOR, 3.0)
