## Versioned persistence for settings and local high scores (plan §10.2, §10.8)
## plus the Milestone 3 high-score foundation: in-memory top-ten tables keyed
## by the difficulty preset's score table (§6.4: assisted/canonical/ace).
##
## Disk persistence — atomic writes, corruption recovery, schema migration,
## and the non-blocking "saving unavailable" state for Web — lands in
## Milestone 5. The schema constants are fixed here so no other system
## invents its own paths or versions.
##
## v1 does NOT persist input bindings or a tutorial-seen flag (§10.2): there is
## no remap UI or interactive tutorial to produce that state.
extends Node

const SETTINGS_PATH := "user://settings.json"
const SCORES_PATH := "user://high_scores.json"
const SCHEMA_VERSION := 1

## §2/§7: local top-ten per table.
const TOP_SCORES := 10

var _score_tables := {}  # StringName -> Array[int], descending


## Records a finished run's score. Returns the 0-based table position, or -1
## when the score didn't place (or is zero).
func record_score(table: StringName, score: int) -> int:
	if score <= 0:
		return -1
	var scores: Array = _score_tables.get_or_add(table, [])
	var index := 0
	while index < scores.size() and scores[index] >= score:
		index += 1
	if index >= TOP_SCORES:
		return -1
	scores.insert(index, score)
	if scores.size() > TOP_SCORES:
		scores.resize(TOP_SCORES)
	return index


func best_score(table: StringName) -> int:
	var scores: Array = _score_tables.get(table, [])
	return scores[0] if not scores.is_empty() else 0


func top_scores(table: StringName) -> Array:
	return _score_tables.get(table, []).duplicate()
