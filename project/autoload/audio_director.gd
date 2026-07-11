## Audio buses, volume control, and music state transitions (plan §10.2).
## No gameplay authority.
##
## Bus wiring, volume options, and pooled one-shot players (only if profiling
## requires them) arrive in Milestone 5. Music itself is optional for v1 (§9);
## music state transitions are a no-op if v1 ships without a track, but the
## Music bus exists regardless.
extends Node

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
