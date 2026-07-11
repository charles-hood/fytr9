## Ordered wave recipes for a run (§6.2 table, waves 1-5) plus the shared
## between-wave pacing. The post-wave-5 endless formulas arrive in Milestone 4.
class_name WaveTable
extends Resource

@export var waves: Array[Resource] = []  # WaveRecipe, in play order

## §6.1 lifecycle pacing: PRE_WAVE breather before spawns begin, and the
## WAVE_COMPLETE hold before the next wave starts.
@export var pre_wave_duration := 2.5
@export var wave_complete_duration := 2.0
