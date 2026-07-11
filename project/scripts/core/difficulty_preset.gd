## One §6.4 difficulty preset. Edit the .tres files under
## resources/balance/difficulty/, not code. RunController resolves the active
## preset from AppState's selection at run start.
class_name DifficultyPreset
extends Resource

@export var id: StringName = &"pilot"
@export var display_name := "PILOT"

## Starting stocks (§6.4). Ship count includes the active ship; both ships and
## bombs cap at 5 during a run (§4.3, §4.4).
@export var lives := 3
@export var bombs := 3

## Multiplies enemy movement and enemy projectile speeds.
@export var enemy_speed_scale := 1.0

## Probability a hyperspace jump destroys the ship (§4.3, §6.4).
@export var hyperspace_failure_chance := 0.10

## Catch forgiveness (§6.4 Large/Standard/Tight) as a catch-radius multiplier.
@export var catch_radius_scale := 1.0

## Terrain collision destroys the ship in Pilot/Ace; Cadet keeps the
## forgiving rebound (§4.2).
@export var lethal_terrain := true

## High-score table this preset records to (§6.4: Assisted/Canonical/Ace).
@export var score_table: StringName = &"canonical"
