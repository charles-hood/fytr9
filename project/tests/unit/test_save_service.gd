## Milestone 3 high-score foundation (§6.4, §7): in-memory top-ten tables per
## difficulty score table. Disk persistence is Milestone 5.
extends "res://tests/test_case.gd"

const SaveServiceScript := preload("res://autoload/save_service.gd")


func test_top_ten_insert_order_and_cap() -> void:
	var save: Node = SaveServiceScript.new()
	assert_eq(save.best_score(&"canonical"), 0, "empty table best is 0")
	assert_eq(save.record_score(&"canonical", 500), 0, "first score tops the table")
	assert_eq(save.record_score(&"canonical", 900), 0, "higher score takes first place")
	assert_eq(save.record_score(&"canonical", 700), 1, "middle score slots between")
	assert_eq(save.best_score(&"canonical"), 900, "best reflects the top entry")
	assert_eq(save.top_scores(&"canonical"), [900, 700, 500], "descending order")

	for i in 10:
		save.record_score(&"canonical", 1000 + i)
	assert_eq(save.top_scores(&"canonical").size(), 10, "table capped at ten (§2)")
	assert_eq(save.record_score(&"canonical", 1), -1, "a score below the table is rejected")
	assert_eq(save.record_score(&"canonical", 0), -1, "zero never places")
	save.free()


func test_tables_are_separate_per_difficulty() -> void:
	var save: Node = SaveServiceScript.new()
	save.record_score(&"canonical", 5000)
	save.record_score(&"assisted", 8000)
	assert_eq(save.best_score(&"canonical"), 5000, "canonical table unaffected by assisted")
	assert_eq(save.best_score(&"assisted"), 8000, "assisted table separate (§6.4, §7)")
	assert_eq(save.best_score(&"ace"), 0, "ace table untouched")
	save.free()
