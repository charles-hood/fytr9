## The three §6.4 difficulty presets as shipped resources.
extends "res://tests/test_case.gd"

const CADET := preload("res://resources/balance/difficulty/cadet.tres")
const PILOT := preload("res://resources/balance/difficulty/pilot.tres")
const ACE := preload("res://resources/balance/difficulty/ace.tres")


func test_preset_table_matches_spec() -> void:
	assert_eq(CADET.lives, 5, "Cadet lives")
	assert_eq(PILOT.lives, 3, "Pilot lives")
	assert_eq(ACE.lives, 3, "Ace lives")
	assert_eq(CADET.bombs, 5, "Cadet bombs")
	assert_eq(PILOT.bombs, 3, "Pilot bombs")
	assert_eq(ACE.bombs, 2, "Ace bombs")
	assert_almost_eq(CADET.enemy_speed_scale, 0.8, 0.0001, "Cadet enemy speed")
	assert_almost_eq(PILOT.enemy_speed_scale, 1.0, 0.0001, "Pilot enemy speed")
	assert_almost_eq(ACE.enemy_speed_scale, 1.2, 0.0001, "Ace enemy speed")
	assert_almost_eq(CADET.hyperspace_failure_chance, 0.0, 0.0001, "Cadet never fails jumps")
	assert_almost_eq(PILOT.hyperspace_failure_chance, 0.10, 0.0001, "Pilot 10%")
	assert_almost_eq(ACE.hyperspace_failure_chance, 0.15, 0.0001, "Ace 15%")


func test_catch_forgiveness_ordering() -> void:
	assert_true(CADET.catch_radius_scale > PILOT.catch_radius_scale,
			"Cadet catch forgiveness is Large")
	assert_almost_eq(PILOT.catch_radius_scale, 1.0, 0.0001, "Pilot is Standard")
	assert_true(ACE.catch_radius_scale < PILOT.catch_radius_scale,
			"Ace catch forgiveness is Tight")


func test_terrain_and_score_tables() -> void:
	assert_false(CADET.lethal_terrain, "Cadet uses the forgiving rebound (§4.2)")
	assert_true(PILOT.lethal_terrain, "Pilot terrain is lethal")
	assert_true(ACE.lethal_terrain, "Ace terrain is lethal")
	assert_eq(CADET.score_table, &"assisted", "Cadet records to the assisted table")
	assert_eq(PILOT.score_table, &"canonical", "Pilot records to the canonical table")
	assert_eq(ACE.score_table, &"ace", "Ace records to its own table")
