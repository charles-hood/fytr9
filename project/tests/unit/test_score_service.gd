## ScoreService (§7): typed-event awards, the single-award-per-entity rule,
## and wave-clear/survivor/perfect bonuses.
extends "res://tests/test_case.gd"

const ScoreServiceScript := preload("res://scripts/core/score_service.gd")
const SCORING := preload("res://resources/balance/scoring_balance.tres")


func test_enemy_awards_once() -> void:
	var service: ScoreService = ScoreServiceScript.new(SCORING)
	service.enemy_destroyed(101, &"snatcher")
	service.enemy_destroyed(101, &"snatcher")
	assert_eq(service.total, 150, "same entity id can never double-award (§7)")
	service.enemy_destroyed(102, &"snatcher")
	assert_eq(service.total, 300, "distinct entities award separately")


func test_rescue_awards() -> void:
	var service: ScoreService = ScoreServiceScript.new(SCORING)
	service.settler_caught()
	assert_eq(service.total, 250, "catch value (§7)")
	service.settler_returned()
	assert_eq(service.total, 1000, "return adds 750 (§7)")


func test_wave_clear_bonuses() -> void:
	var service: ScoreService = ScoreServiceScript.new(SCORING)
	service.wave_cleared(1, 7, 10)
	assert_eq(service.total, 100 + 7 * 100, "wave 1 clear + 7 survivors, no perfect bonus")

	var perfect: ScoreService = ScoreServiceScript.new(SCORING)
	perfect.wave_cleared(1, 10, 10)
	assert_eq(perfect.total, 100 + 1000 + (1000 + 100),
			"perfect population adds 1000 + 100 × wave (§7)")


func test_score_changed_signal() -> void:
	var service: ScoreService = ScoreServiceScript.new(SCORING)
	var seen := [0]
	service.score_changed.connect(func(total): seen[0] = total)
	service.enemy_destroyed(5, &"snatcher")
	assert_eq(seen[0], 150, "signal carries the running total")
