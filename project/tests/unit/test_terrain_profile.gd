## Terrain must join continuously at the seam (plan §4.1) and answer
## queries for any wrapped or unwrapped x.
extends "res://tests/test_case.gd"

const TerrainProfileScript := preload("res://scripts/core/terrain_profile.gd")

const W := 3840.0


func test_seam_continuity() -> void:
	var terrain := TerrainProfileScript.new(W)
	assert_almost_eq(terrain.get_surface_y(0.0), terrain.get_surface_y(W), 0.0001,
			"exact seam matches")
	var just_before: float = terrain.get_surface_y(W - 0.01)
	var just_after: float = terrain.get_surface_y(0.01)
	assert_true(absf(just_before - just_after) < 0.5,
			"no step across seam (%.4f vs %.4f)" % [just_before, just_after])


func test_continuity_everywhere() -> void:
	var terrain := TerrainProfileScript.new(W)
	var step := 4.0
	var max_jump := 0.0
	var x := 0.0
	var prev: float = terrain.get_surface_y(0.0)
	while x < W:
		x += step
		var y: float = terrain.get_surface_y(x)
		max_jump = maxf(max_jump, absf(y - prev))
		prev = y
	assert_true(max_jump < 6.0, "max 4px-step jump %.3f stays gentle" % max_jump)


func test_unwrapped_queries_match_normalized() -> void:
	var terrain := TerrainProfileScript.new(W)
	for x in [100.0, 2000.0, W - 1.0]:
		assert_almost_eq(terrain.get_surface_y(x + W), terrain.get_surface_y(x), 0.0001,
				"one wrap ahead matches at %s" % x)
		assert_almost_eq(terrain.get_surface_y(x - 3.0 * W), terrain.get_surface_y(x), 0.0001,
				"multi-wrap behind matches at %s" % x)


func test_surface_band() -> void:
	var terrain := TerrainProfileScript.new(W)
	var x := 0.0
	while x < W:
		var y: float = terrain.get_surface_y(x)
		assert_true(y >= terrain.min_surface_y() - 0.001 and y <= 700.0,
				"surface y %.1f at x=%s within band" % [y, x])
		x += 16.0
