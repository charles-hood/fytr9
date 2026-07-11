## Scoring values (plan §7). All provisional balance resources.
## Edit the .tres, not code. ScoreService is the only consumer (§10.6).
class_name ScoringBalance
extends Resource

@export var destroy_snatcher := 150
@export var destroy_ravager := 250
@export var destroy_mine_layer := 200
@export var destroy_brood_pod := 500
@export var destroy_splinter := 75
@export var destroy_interceptor := 300

@export var catch_settler := 250
@export var return_settler := 750

## Wave clear: wave_clear_per_wave × wave. Survivors: per_settler × wave each.
## Perfect population: perfect_base + perfect_per_wave × wave.
@export var wave_clear_per_wave := 100
@export var survivor_per_wave := 100
@export var perfect_base := 1000
@export var perfect_per_wave := 100


func enemy_value(kind: StringName) -> int:
	match kind:
		&"snatcher": return destroy_snatcher
		&"ravager": return destroy_ravager
		&"mine_layer": return destroy_mine_layer
		&"brood_pod": return destroy_brood_pod
		&"splinter": return destroy_splinter
		&"interceptor": return destroy_interceptor
	push_error("unknown enemy kind: %s" % kind)
	return 0
