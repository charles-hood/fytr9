## Sanity checks proving the runner discovers suites and the assert helpers
## behave. Real subject-matter tests (ring math, Settler states, waves,
## scoring, saves) arrive with their systems in Milestones 1+.
extends "res://tests/test_case.gd"


func test_runner_executes() -> void:
	assert_true(true, "runner executes test methods")


func test_equality_helpers() -> void:
	assert_eq(2 + 2, 4, "integer equality")
	assert_false(1 == 2, "assert_false works")
	assert_almost_eq(0.1 + 0.2, 0.3, 0.000001, "float tolerance")
