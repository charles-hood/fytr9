## Snatcher tuning (plan §5 roster row). Edit the .tres, not code.
## Aimed shots (every 2.0 s) are deferred to Milestone 3 with player death —
## see docs/DECISIONS.md.
class_name SnatcherBalance
extends Resource

## §5: descend 80, ascend 60.
@export var descend_speed := 80.0
@export var ascend_speed := 60.0

## Horizontal patrol while waiting for an abduction slot.
@export var patrol_speed := 80.0
@export var patrol_y_min := 100.0
@export var patrol_y_max := 200.0
@export var patrol_turn_min := 1.5
@export var patrol_turn_max := 4.0

## Grab geometry: claw point sits grab_offset_y above the Settler's center;
## the grab completes within grab_radius. Must equal carry_offset_y so the
## Settler is picked up exactly where it stands (no ground clipping).
@export var grab_offset_y := 22.0
@export var grab_radius := 14.0

## Carried Settler hangs this far below the Snatcher.
@export var carry_offset_y := 22.0

## Upper escape boundary (§4.5): reaching this y mutates the Settler.
@export var escape_y := 60.0

@export var hit_radius := 16.0
