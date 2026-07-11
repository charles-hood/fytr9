## Minimal dependency-free test base (plan §12). Test scripts under
## res://tests/unit and res://tests/integration extend this and define
## methods named test_*; the runner discovers and calls them.
extends RefCounted

var checks := 0
var failures: Array[String] = []
var current_test := ""

## Set by the runner; lets tests add nodes under scene_tree.root when a
## test subject needs to live in the tree (free them before returning).
var scene_tree: SceneTree


func fail_test(message: String) -> void:
	failures.append("%s: %s" % [current_test, message])


func assert_true(condition: bool, message: String = "expected true") -> void:
	checks += 1
	if not condition:
		fail_test(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if actual != expected:
		fail_test("%s — expected %s, got %s" % [message, expected, actual])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		fail_test("%s — expected %s ± %s, got %s" % [message, expected, tolerance, actual])
