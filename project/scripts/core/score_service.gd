## ScoreService (plan §7, §10.6): the only path by which score is awarded.
## Actors never award score directly — RunController routes typed domain
## events here. A destroyed entity awards exactly once (guarded by instance
## id); Settler catch/return events are inherently single-fire per transition
## via the coordinator's state machine, and one Settler may legitimately
## award multiple catches across separate falls.
class_name ScoreService
extends RefCounted

signal score_changed(total: int)

var total := 0
var balance: Resource  # ScoringBalance

var _awarded_entities := {}


func _init(p_balance: Resource) -> void:
	balance = p_balance


func enemy_destroyed(entity_id: int, kind: StringName) -> void:
	if _awarded_entities.has(entity_id):
		return
	_awarded_entities[entity_id] = true
	_add(balance.enemy_value(kind))


func settler_caught() -> void:
	_add(balance.catch_settler)


func settler_returned() -> void:
	_add(balance.return_settler)


func wave_cleared(wave: int, survivors: int, full_population: int) -> void:
	var bonus: int = balance.wave_clear_per_wave * wave
	bonus += balance.survivor_per_wave * wave * survivors
	if survivors == full_population:
		bonus += balance.perfect_base + balance.perfect_per_wave * wave
	_add(bonus)


func _add(points: int) -> void:
	if points == 0:
		return
	total += points
	score_changed.emit(total)
