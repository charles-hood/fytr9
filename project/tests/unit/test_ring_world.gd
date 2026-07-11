## Exhaustive ring-math tests (plan §12): negative X, zero, exact seam,
## just before/after seam, multiple world widths, half-world tie behavior,
## shortest-path targeting across the seam, camera-relative positions.
extends "res://tests/test_case.gd"

const RingWorldScript := preload("res://scripts/core/ring_world.gd")

const W := 3840.0
const EPS := 0.0001


func _ring() -> RingWorld:
	return RingWorldScript.new(W)


func test_normalize_x() -> void:
	var ring := _ring()
	assert_almost_eq(ring.normalize_x(0.0), 0.0, EPS, "zero")
	assert_almost_eq(ring.normalize_x(100.0), 100.0, EPS, "in range")
	assert_almost_eq(ring.normalize_x(W), 0.0, EPS, "exact seam wraps to 0")
	assert_almost_eq(ring.normalize_x(W - 0.5), W - 0.5, EPS, "just before seam")
	assert_almost_eq(ring.normalize_x(W + 0.5), 0.5, EPS, "just after seam")
	assert_almost_eq(ring.normalize_x(-1.0), W - 1.0, EPS, "negative")
	assert_almost_eq(ring.normalize_x(-W), 0.0, EPS, "negative full wrap")
	assert_almost_eq(ring.normalize_x(-W - 10.0), W - 10.0, EPS, "negative multi-wrap")
	assert_almost_eq(ring.normalize_x(7.0 * W + 3.0), 3.0, EPS, "multiple world widths")
	assert_almost_eq(ring.normalize_x(-3.0 * W + 42.0), 42.0, EPS, "negative multiple widths")


func test_normalize_range_property() -> void:
	var ring := _ring()
	for x in [-99999.0, -W * 2.5, -1.0, 0.0, 1.0, W * 0.5, W - 0.001, W, W * 3.7, 123456.0]:
		var n: float = ring.normalize_x(x)
		assert_true(n >= 0.0 and n < W, "normalize(%s)=%s in [0,W)" % [x, n])


func test_wrapped_delta_shortest_path() -> void:
	var ring := _ring()
	assert_almost_eq(ring.wrapped_delta_x(0.0, 0.0), 0.0, EPS, "self")
	assert_almost_eq(ring.wrapped_delta_x(100.0, 300.0), 200.0, EPS, "simple forward")
	assert_almost_eq(ring.wrapped_delta_x(300.0, 100.0), -200.0, EPS, "simple backward")
	# Across the seam: from x=40 to x=3800 the short route is 80 px backward.
	assert_almost_eq(ring.wrapped_delta_x(40.0, W - 40.0), -80.0, EPS,
			"targeting across seam goes backward")
	assert_almost_eq(ring.wrapped_delta_x(W - 40.0, 40.0), 80.0, EPS,
			"targeting across seam goes forward")
	# Unnormalized inputs use the same ring.
	assert_almost_eq(ring.wrapped_delta_x(-10.0, 10.0), 20.0, EPS, "negative from")
	assert_almost_eq(ring.wrapped_delta_x(W * 2.0 + 5.0, 10.0), 5.0, EPS, "multi-wrap from")


func test_wrapped_delta_half_world_tie() -> void:
	var ring := _ring()
	# The exact half-world tie is defined to resolve to -width/2 (§10.3).
	assert_almost_eq(ring.wrapped_delta_x(0.0, W / 2.0), -W / 2.0, EPS, "tie resolves negative")
	assert_almost_eq(ring.wrapped_delta_x(100.0, 100.0 + W / 2.0), -W / 2.0, EPS,
			"tie from nonzero origin")
	# Just off the tie resolves to the genuinely shorter side.
	assert_almost_eq(ring.wrapped_delta_x(0.0, W / 2.0 - 1.0), W / 2.0 - 1.0, EPS,
			"just under half goes forward")
	assert_almost_eq(ring.wrapped_delta_x(0.0, W / 2.0 + 1.0), -(W / 2.0 - 1.0), EPS,
			"just over half goes backward")


func test_wrapped_delta_range_property() -> void:
	var ring := _ring()
	for from_x in [0.0, 17.0, W - 3.0, W * 1.5, -250.0]:
		for to_x in [0.0, 5.0, W / 2.0, W - 5.0, -W, W * 2.2]:
			var d: float = ring.wrapped_delta_x(from_x, to_x)
			assert_true(d >= -W / 2.0 and d < W / 2.0,
					"delta(%s,%s)=%s in [-W/2,W/2)" % [from_x, to_x, d])


func test_wrapped_distance() -> void:
	var ring := _ring()
	assert_almost_eq(ring.wrapped_distance_x(40.0, W - 40.0), 80.0, EPS, "seam distance")
	assert_almost_eq(ring.wrapped_distance_x(W - 40.0, 40.0), 80.0, EPS, "symmetric")
	assert_almost_eq(ring.wrapped_distance_x(0.0, W / 2.0), W / 2.0, EPS, "max distance")
	assert_almost_eq(ring.wrapped_distance_x(123.0, 123.0), 0.0, EPS, "zero distance")


func test_camera_relative_x() -> void:
	var ring := _ring()
	# Entity just across the seam from the camera appears just to the right.
	assert_almost_eq(ring.camera_relative_x(10.0, W - 30.0), 40.0, EPS,
			"across seam appears right")
	assert_almost_eq(ring.camera_relative_x(W - 30.0, 10.0), -40.0, EPS,
			"across seam appears left")
	assert_almost_eq(ring.camera_relative_x(500.0, 200.0), 300.0, EPS, "plain offset")
