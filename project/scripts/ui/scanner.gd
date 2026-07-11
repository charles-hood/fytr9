## Scanner (plan §11): fixed HUD Control, drawn procedurally from
## ThreatRegistry contacts — never from scene-tree searches. Maps normalized
## world X to scanner X, gameplay Y coarsely to scanner Y, and shows the
## current viewport bracket seam-aware (split into two segments when the
## view crosses the seam).
##
## The mapping functions are static and pure for headless testing (§12).
extends Control

const WORLD_Y_TOP := 0.0
const WORLD_Y_BOTTOM := 720.0
const VIEW_WIDTH := 1280.0

const COLOR_FRAME := Color(1.0, 0.8, 0.0, 0.5)
const COLOR_BRACKET := Color(1.0, 0.8, 0.0, 0.9)

## Icon class per contact kind: color + shape ("dot" round-ish square,
## "block" tall block, "tri" downward triangle). Shape differs per state so
## color is never the only signal (§8).
const ICONS := {
	&"player": {"color": Color("00FF88"), "shape": "dot", "size": 3.0},
	&"snatcher": {"color": Color("FF6600"), "shape": "block", "size": 3.0},
	&"settler": {"color": Color("FFFFCC"), "shape": "dot", "size": 2.0},
	&"settler_carried": {"color": Color("FF6600"), "shape": "tri", "size": 4.0},
	&"settler_falling": {"color": Color("FFFFCC"), "shape": "tri", "size": 4.0},
}

var _contacts: Array[Dictionary] = []
var _cam_sim_x := 0.0
var _world_width := 3840.0


static func map_x(sim_x: float, world_width: float, scanner_width: float) -> float:
	return fposmod(sim_x, world_width) / world_width * scanner_width


static func map_y(sim_y: float, scanner_height: float) -> float:
	var t := clampf((sim_y - WORLD_Y_TOP) / (WORLD_Y_BOTTOM - WORLD_Y_TOP), 0.0, 1.0)
	return t * scanner_height


## Viewport bracket as 1-2 [start_px, width_px] segments in scanner space;
## two segments when the view straddles the seam.
static func bracket_segments(cam_sim_x: float, world_width: float, scanner_width: float) -> Array:
	var left := fposmod(cam_sim_x - VIEW_WIDTH / 2.0, world_width)
	var view_scanner_width := VIEW_WIDTH / world_width * scanner_width
	var start := left / world_width * scanner_width
	if start + view_scanner_width <= scanner_width:
		return [[start, view_scanner_width]]
	var first_width := scanner_width - start
	return [[start, first_width], [0.0, view_scanner_width - first_width]]


static func icon_for(kind: StringName) -> Dictionary:
	return ICONS.get(kind, {"color": Color.MAGENTA, "shape": "dot", "size": 3.0})


func update_contacts(registry: ThreatRegistry, cam_sim_x: float, world_width: float) -> void:
	_contacts = registry.contacts
	_cam_sim_x = cam_sim_x
	_world_width = world_width
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.05, 0.12, 0.85), true)
	draw_rect(Rect2(0, 0, w, h), COLOR_FRAME, false, 1.0)
	for segment in bracket_segments(_cam_sim_x, _world_width, w):
		draw_rect(Rect2(segment[0], 0, segment[1], h), COLOR_BRACKET, false, 1.0)
	for contact in _contacts:
		var icon := icon_for(contact["kind"])
		var x: float = map_x(contact["sim_x"], _world_width, w)
		var y: float = map_y(contact["sim_y"], h)
		var s: float = icon["size"]
		match icon["shape"]:
			"dot":
				draw_rect(Rect2(x - s, y - s, s * 2.0, s * 2.0), icon["color"], true)
			"block":
				draw_rect(Rect2(x - s, y - s * 1.6, s * 2.0, s * 3.2), icon["color"], true)
			"tri":
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - s, y - s), Vector2(x + s, y - s), Vector2(x, y + s),
				]), icon["color"])
