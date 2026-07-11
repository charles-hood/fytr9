## Scanner mapping (§11, §12): entity at X=0 and X≈world width, viewport
## bracket crossing the seam, icon class per contact kind, and coarse Y
## mapping.
extends "res://tests/test_case.gd"

const ScannerScript := preload("res://scripts/ui/scanner.gd")

const W := 3840.0
const SW := 400.0  # scanner width px
const SH := 68.0   # scanner height px


func test_map_x_boundaries() -> void:
	assert_almost_eq(ScannerScript.map_x(0.0, W, SW), 0.0, 0.001, "x=0 maps to left edge")
	var near_seam: float = ScannerScript.map_x(W - 1.0, W, SW)
	assert_true(near_seam > SW - 1.0 and near_seam < SW, "x≈W maps to right edge")
	assert_almost_eq(ScannerScript.map_x(W, W, SW), 0.0, 0.001, "x=W wraps to left edge")
	assert_almost_eq(ScannerScript.map_x(W / 2.0, W, SW), SW / 2.0, 0.001, "midpoint centered")
	assert_almost_eq(ScannerScript.map_x(-10.0, W, SW), (W - 10.0) / W * SW, 0.001,
			"negative input normalizes")


func test_map_y_coarse() -> void:
	assert_almost_eq(ScannerScript.map_y(0.0, SH), 0.0, 0.001, "top of world → top")
	assert_almost_eq(ScannerScript.map_y(720.0, SH), SH, 0.001, "bottom of world → bottom")
	assert_almost_eq(ScannerScript.map_y(360.0, SH), SH / 2.0, 0.001, "middle altitude")
	assert_almost_eq(ScannerScript.map_y(-50.0, SH), 0.0, 0.001, "clamped above")
	assert_almost_eq(ScannerScript.map_y(900.0, SH), SH, 0.001, "clamped below")


func test_bracket_single_segment() -> void:
	var segments: Array = ScannerScript.bracket_segments(W / 2.0, W, SW)
	assert_eq(segments.size(), 1, "mid-world view is one segment")
	var expected_width := 1280.0 / W * SW
	assert_almost_eq(segments[0][1], expected_width, 0.001, "bracket width matches viewport")
	assert_almost_eq(segments[0][0], (W / 2.0 - 640.0) / W * SW, 0.001, "bracket start")


func test_bracket_crossing_seam_splits() -> void:
	var segments: Array = ScannerScript.bracket_segments(0.0, W, SW)
	assert_eq(segments.size(), 2, "seam-straddling view splits into two segments")
	var total: float = segments[0][1] + segments[1][1]
	assert_almost_eq(total, 1280.0 / W * SW, 0.001, "split widths sum to the full bracket")
	assert_almost_eq(segments[1][0], 0.0, 0.001, "second segment starts at scanner left")
	assert_true(segments[0][0] + segments[0][1] >= SW - 0.01,
			"first segment runs to the scanner's right edge")


func test_icon_classes() -> void:
	assert_eq(ScannerScript.icon_for(&"player")["color"], Color("00FF88"), "player color")
	assert_eq(ScannerScript.icon_for(&"snatcher")["shape"], "block", "snatcher shape")
	assert_eq(ScannerScript.icon_for(&"settler")["shape"], "dot", "settler shape")
	assert_eq(ScannerScript.icon_for(&"settler_falling")["shape"], "tri",
			"falling settler differs by shape, not just color (§8)")
	assert_eq(ScannerScript.icon_for(&"settler_carried")["shape"], "tri", "carried shape")
	assert_true(ScannerScript.icon_for(&"settler_carried")["color"]
			!= ScannerScript.icon_for(&"settler_falling")["color"],
			"carried vs falling differ by color too")
