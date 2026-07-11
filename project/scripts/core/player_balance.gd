## Player movement/weapon tuning (plan §0.4, §4.2). Edit the .tres, not code.
##
## The §4.2 starting values were inherited from a 640x360-canvas draft; their
## viewport-relative derivations at 1280x720 are recorded in
## docs/DECISIONS.md and remain subject to the Milestone 1 feel check.
class_name PlayerBalance
extends Resource

@export var max_horizontal_speed := 400.0
@export var max_vertical_speed := 260.0

## Seconds from standstill to max horizontal speed (§4.2: 0.40-0.55).
@export var time_to_max_speed := 0.45

## Total seconds for a full-speed reversal, +max to -max (§4.2: 0.50-0.70).
## Braking is the fast phase (reversal_time - time_to_max_speed); the rebuild
## to max speed then takes time_to_max_speed.
@export var reversal_time := 0.6

## Deceleration applied when horizontal input is released (moderate inertial
## damping, §4.2) — from max speed this coasts to a stop in max/release_decel s.
@export var release_decel := 500.0

## Arc Lance (§4.3): shots per second, projectile px/s, seconds alive.
## Lifetime is the shot cap mechanism — no artificial low shot count (§16).
@export var fire_rate := 9.0
@export var projectile_speed := 800.0
@export var projectile_lifetime := 1.1
@export var muzzle_offset := 20.0

## Camera look-ahead as a fraction of viewport width (§4.2: 20-25%),
## scaled by current velocity and smoothed at camera_lookahead_response.
@export var camera_lookahead_fraction := 0.22
@export var camera_lookahead_response := 4.0

## Used from Milestone 3 (lives/respawn); centralized now so no literal
## sneaks into scripts later (§4.2).
@export var respawn_invulnerability := 1.5
@export var hyperspace_invulnerability := 0.75
