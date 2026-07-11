## World-level tuning values (plan §0.4, §4.1). Edit the .tres, not code.
class_name WorldBalance
extends Resource

## Ring circumference in logical px. 3 viewport widths to start; balance
## range to test is 2.5-4 viewports (§4.1).
@export var world_width := 3840.0

## Top of the playable vertical band (scene y, +down).
@export var min_player_y := 40.0

## Minimum clearance kept between the player and the terrain surface in the
## Milestone 1 flight lab (rebound behavior; lethal collision arrives with
## lives in Milestone 3 — see docs/DECISIONS.md).
@export var terrain_clearance := 20.0
