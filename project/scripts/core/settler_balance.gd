## Settler tuning (plan §0.4, §4.5). Edit the .tres, not code.
class_name SettlerBalance
extends Resource

## Settlers on a fresh planet (§2, §4.5).
@export var population := 10

## Ground walking (SAFE/TARGETED); direction/interval draw from gameplay_rng.
@export var walk_speed := 25.0
@export var walk_interval_min := 1.0
@export var walk_interval_max := 3.0

## Feet-to-center offset above the terrain surface.
@export var ground_offset := 8.0

## Falling (§4.5): gravity, terminal speed, and the survivable fall distance —
## drops taller than this cause LOST.
@export var fall_gravity := 500.0
@export var max_fall_speed := 320.0
@export var safe_fall_distance := 130.0

## Catch-by-overlap radius (§4.5; difficulty presets scale this later, §6.4).
@export var catch_radius := 42.0

## Carried Settler hangs this far below the craft; extra carried Settlers
## stack a bit lower each.
@export var carry_offset_y := 26.0
@export var carry_stack_spacing := 18.0

## Safe drop band (§4.5): carrying the Settler within this height above the
## surface returns it to the ground.
@export var drop_band_height := 60.0

## DELIVERED protected state duration before returning to SAFE.
@export var delivered_duration := 2.0
