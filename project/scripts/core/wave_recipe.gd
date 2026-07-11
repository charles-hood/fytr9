## One wave's encounter recipe (plan §6.2). Milestone 2 ships the wave-1 row
## only; the full table and post-5 formulas arrive in Milestones 3-4.
class_name WaveRecipe
extends Resource

@export var wave_number := 1
@export var snatcher_count := 4
@export var max_concurrent_snatchers := 2

## §5/§6.2: early waves cap active abductions at 1.
@export var abduction_cap := 1

## Spawn pacing (drawn from encounter_rng only, §6.3).
@export var spawn_interval_min := 2.5
@export var spawn_interval_max := 5.0

## §5: no spawns inside the immediate camera safety radius.
@export var spawn_min_player_distance := 600.0
