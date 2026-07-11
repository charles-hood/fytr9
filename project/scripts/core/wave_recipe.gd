## One wave's encounter recipe (plan §6.2). Waves 1-5 ship in Milestone 3
## (resources/encounters/waves_01_05.tres); the post-5 formulas arrive in M4.
class_name WaveRecipe
extends Resource

@export var wave_number := 1
@export var snatcher_count := 4
@export var max_concurrent_snatchers := 2

## §5/§6.2: early waves cap active abductions at 1.
@export var abduction_cap := 1

## §6.2 columns authored now but spawned from Milestone 4, when the Mine
## Layer/Brood Pod/Ravager roster and the Interceptor anti-stall exist.
@export var mine_layer_count := 0
@export var brood_pod_count := 0
@export var ravagers_at_start := 0
@export var interceptor_timer_sec := 45.0

## Spawn pacing (drawn from encounter_rng only, §6.3).
@export var spawn_interval_min := 2.5
@export var spawn_interval_max := 5.0

## §5: no spawns inside the immediate camera safety radius.
@export var spawn_min_player_distance := 600.0
