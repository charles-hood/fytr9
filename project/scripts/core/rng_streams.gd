## The three explicitly-scoped random streams (plan §6.3). Nothing gameplay-
## or encounter-affecting may pull from Godot's global RNG.
##
## - encounter: owned exclusively by WaveDirector; obtained per wave via
##   make_encounter_rng() so each wave's schedule derives from
##   (run_seed, wave_number) alone.
## - gameplay: hyperspace rolls, enemy AI timing, Settler walking choices.
##   Seeded per run but not required to be reproducible run-to-run.
## - cosmetic: particle/SFX variation only. Never touches gameplay state.
##
## If a cosmetic or AI-timing change ever appears to shift wave composition,
## a system reached into the wrong stream — fix the boundary (§16).
class_name RngStreams
extends RefCounted

var run_seed: int
var gameplay := RandomNumberGenerator.new()
var cosmetic := RandomNumberGenerator.new()


func _init(p_run_seed: int) -> void:
	run_seed = p_run_seed
	gameplay.seed = derive_seed(p_run_seed, "gameplay", 0)
	cosmetic.seed = derive_seed(p_run_seed, "cosmetic", 0)


## Fresh, deterministically seeded generator for one wave's encounter
## schedule (§6.3: encounter seed derives from run seed and wave number).
## WaveDirector owns the returned generator.
func make_encounter_rng(wave_number: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive_seed(run_seed, "encounter", wave_number)
	return rng


## Deterministic within a pinned engine build (GDScript hash() of a given
## String is stable for a given Godot version, which is pinned — README).
static func derive_seed(p_run_seed: int, stream: String, index: int) -> int:
	return hash("%d:%s:%d" % [p_run_seed, stream, index])
