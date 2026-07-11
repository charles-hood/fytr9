## The three scoped RNG streams (plan §6.3): encounter schedules must be
## reproducible from (run_seed, wave_number) alone, and drawing from the
## gameplay/cosmetic streams must never perturb encounter sequences.
extends "res://tests/test_case.gd"

const RngStreamsScript := preload("res://scripts/core/rng_streams.gd")


func _sequence(rng: RandomNumberGenerator, count: int) -> Array:
	var values := []
	for i in count:
		values.append(rng.randi())
	return values


func test_encounter_rng_reproducible() -> void:
	var a := RngStreamsScript.new(12345)
	var b := RngStreamsScript.new(12345)
	for wave in [1, 2, 7]:
		assert_eq(_sequence(a.make_encounter_rng(wave), 10),
				_sequence(b.make_encounter_rng(wave), 10),
				"wave %d schedule reproducible from same run seed" % wave)


func test_encounter_rng_varies_by_wave_and_seed() -> void:
	var streams := RngStreamsScript.new(12345)
	assert_true(_sequence(streams.make_encounter_rng(1), 10)
			!= _sequence(streams.make_encounter_rng(2), 10),
			"different waves get different schedules")
	var other := RngStreamsScript.new(54321)
	assert_true(_sequence(streams.make_encounter_rng(1), 10)
			!= _sequence(other.make_encounter_rng(1), 10),
			"different run seeds get different schedules")


func test_gameplay_draws_do_not_perturb_encounters() -> void:
	# Same run seed; one instance burns gameplay/cosmetic rolls first.
	var quiet := RngStreamsScript.new(999)
	var noisy := RngStreamsScript.new(999)
	for i in 100:
		noisy.gameplay.randf()
		noisy.cosmetic.randf()
	assert_eq(_sequence(quiet.make_encounter_rng(3), 10),
			_sequence(noisy.make_encounter_rng(3), 10),
			"gameplay/cosmetic draws never shift the encounter schedule")


func test_streams_are_distinct() -> void:
	var streams := RngStreamsScript.new(42)
	var gameplay_first := streams.gameplay.randi()
	var cosmetic_first := streams.cosmetic.randi()
	# Distinct seeds derived per stream; a collision here would mean the
	# derivation ignores the stream name.
	assert_true(streams.gameplay.seed != streams.cosmetic.seed,
			"gameplay and cosmetic streams seeded independently")
	assert_true(gameplay_first != cosmetic_first
			or streams.gameplay.randi() != streams.cosmetic.randi(),
			"streams do not produce identical sequences")
