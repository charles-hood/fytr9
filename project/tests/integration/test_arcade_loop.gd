## Milestone 3 exit-criteria drills through the real session scene: a
## complete five-wave Pilot run with exact §7 scoring and the §4.4 extra-ship
## award, the death/respawn/invulnerability flow, difficulty-preset lethality,
## reward thresholds, and the §6.1 simultaneous-event rules (game-over beats
## wave-clear; carried Settlers block completion).
##
## Phase int values mirror RunController.Phase:
## 0 PRE_WAVE, 1 ACTIVE, 2 CLEAR_PENDING, 3 WAVE_COMPLETE.
extends "res://tests/test_case.gd"

const SESSION_SCENE := preload("res://scenes/game/game_session.tscn")
const SettlerScript := preload("res://scripts/actors/settler.gd")

const DT := 1.0 / 60.0


func _spawn_session(seed_value: int, difficulty := 1) -> Node2D:
	var session: Node2D = SESSION_SCENE.instantiate()
	session.get_node("RunController").fixed_seed = seed_value
	session.get_node("RunController").forced_difficulty = difficulty
	scene_tree.root.add_child(session)
	return session


func _free_session(session: Node2D) -> void:
	scene_tree.root.remove_child(session)
	session.free()


func _step(world: Node2D, ticks: int) -> void:
	for i in ticks:
		world._physics_process(DT)


func test_five_wave_pilot_run_completes_with_exact_score() -> void:
	var session := _spawn_session(31415)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var results: Array = []
	run.run_ended.connect(func(result, stats): results.append([result, stats]))

	var ticks := 0
	var waves_seen := {}
	while not run.run_over and ticks < 30000:
		world._physics_process(DT)
		ticks += 1
		waves_seen[run.wave_number] = true
		# Perfect play: every snatcher dies the tick it appears.
		for enemy in world.enemies.duplicate():
			enemy.take_hit()
	assert_true(run.run_over, "run ends within 500 simulated seconds")
	assert_eq(results.size(), 1, "run_ended emitted exactly once")
	assert_eq(results[0][0], &"run_complete", "clearing wave 5 completes the M3 run")
	assert_eq(waves_seen.size(), 5, "all five §6.2 waves were played")
	assert_eq(results[0][1]["wave"], 5, "final stats report wave 5")
	# Kills: (4+5+6+7+8) × 150 = 4500. Per wave w with all 10 settlers alive:
	# clear 100w + survivors 10×100w + perfect 1000+100w = 1200w + 1000;
	# summed over waves 1-5 that is 23000. Total 27500 (§7).
	assert_eq(run.score_service.total, 27500, "five perfect waves score exactly per §7")
	assert_eq(results[0][1]["settlers"], 10, "no settler lost to instant kills")
	# 27500 crosses the single 10k threshold (§4.4): 3+1 ships, 3+1 bombs.
	assert_eq(run.lives, 4, "extra ship awarded at 10k, none at 60k yet")
	assert_eq(run.bombs, 4, "extra ship brings +1 pulse bomb (§4.3)")
	_free_session(session)


func test_death_respawn_invulnerability_and_lives() -> void:
	var session := _spawn_session(777)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")

	run.report_player_death(&"test")
	assert_false(world.player.alive, "death stops the craft")
	assert_eq(run.lives, 2, "a life is consumed")
	_step(world, int(world.player_balance.respawn_delay / DT) + 1)
	assert_true(world.player.alive, "respawns after the §4.4 pause")
	assert_almost_eq(world.player.invuln_timer,
			world.player_balance.respawn_invulnerability, 0.05,
			"respawn grants 1.5s invulnerability (§4.2)")
	assert_almost_eq(world.player.position.y, world.player_balance.respawn_y, 0.001,
			"respawn at the safe altitude")
	_free_session(session)


func test_death_releases_carried_settler_to_falling() -> void:
	var session := _spawn_session(778)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var settler: Node2D = world.settlers[0]
	settler.apply_state(SettlerScript.State.CARRIED_BY_PLAYER)

	run.report_player_death(&"test")
	assert_eq(settler.state, SettlerScript.State.FALLING,
			"carried settler released into FALLING on ship loss (§4.4 step 3)")
	_free_session(session)


func test_respawn_clears_safety_zone() -> void:
	var session := _spawn_session(779)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var player: CharacterBody2D = world.player

	run.report_player_death(&"test")
	world.spawn_snatcher(world.ring.normalize_x(player.sim_x + 50.0))
	world.spawn_enemy_shot({"sim_x": world.ring.normalize_x(player.sim_x + 10.0),
			"y": player.position.y, "velocity": Vector2.ZERO})
	_step(world, int(world.player_balance.respawn_delay / DT) + 1)

	assert_true(player.alive, "respawned")
	assert_eq(world.enemy_shots.size(), 0,
			"hostile projectiles inside the safety radius cleared (§4.4)")
	for enemy in world.enemies:
		assert_true(world.ring.wrapped_distance_x(player.sim_x, enemy.sim_x)
				>= world.player_balance.respawn_safety_radius - 10.0,
				"enemies pushed to the safety-radius edge (§4.4)")
	_free_session(session)


func test_game_over_on_last_life_and_no_respawn() -> void:
	var session := _spawn_session(780)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var results: Array = []
	run.run_ended.connect(func(result, stats): results.append([result, stats]))

	run.lives = 1
	run.report_player_death(&"test")
	assert_true(run.run_over, "no ships left ends the run")
	assert_eq(results.size(), 1, "run_ended emitted exactly once")
	assert_eq(results[0][0], &"game_over", "result is game over")
	_step(world, 300)
	assert_false(world.player.alive, "no respawn after game over")
	assert_eq(results.size(), 1, "still exactly one run_ended")
	_free_session(session)


func test_game_over_wins_simultaneous_wave_clear() -> void:
	var session := _spawn_session(781)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")
	var results: Array = []
	run.run_ended.connect(func(result, stats): results.append([result, stats]))

	var ticks := 0
	while world.enemies.is_empty() and ticks < 900:
		world._physics_process(DT)
		ticks += 1
	assert_false(world.enemies.is_empty(), "a snatcher is on the field")
	run.wave_director.remaining = 0  # exhaust the budget
	var kills: int = world.enemies.size()
	run.lives = 1
	# Same tick: the field clears AND the last ship dies. §6.1: game-over wins.
	for enemy in world.enemies.duplicate():
		enemy.take_hit()
	run.report_player_death(&"test")
	world._physics_process(DT)
	assert_eq(results.size(), 1, "exactly one run end")
	assert_eq(results[0][0], &"game_over", "game over wins the simultaneous tie (§6.1)")
	assert_eq(run.score_service.total, kills * 150,
			"no wave-clear bonus awarded after the tie (§6.1)")
	_free_session(session)


func test_carried_settler_blocks_wave_completion() -> void:
	var session := _spawn_session(782)
	var world: Node2D = session.get_node("World")
	var run: Node = session.get_node("RunController")

	_step(world, int(2.5 / DT) + 2)  # through PRE_WAVE
	assert_eq(run.phase, 1, "wave is ACTIVE")
	run.wave_director.remaining = 0
	for enemy in world.enemies.duplicate():
		enemy.take_hit()
	var settler: Node2D = world.settlers[0]
	settler.apply_state(SettlerScript.State.CARRIED_BY_PLAYER)
	var kills_score: int = run.score_service.total
	_step(world, 10)
	assert_eq(run.phase, 2, "wave stuck in CLEAR_PENDING while a settler is carried (§6.1)")
	assert_eq(run.score_service.total, kills_score, "no wave bonus yet")

	settler.apply_state(SettlerScript.State.SAFE)  # resolve the transition
	_step(world, 2)
	assert_eq(run.phase, 3, "wave completes once the transition resolves")
	assert_eq(run.score_service.total, kills_score + 1200 + 1000,
			"wave 1 clear + survivor + perfect bonuses awarded once (§7)")
	_free_session(session)


func test_extra_ship_thresholds_and_caps() -> void:
	var session := _spawn_session(783)
	var run: Node = session.get_node("RunController")

	run._on_score_changed(9999)
	assert_eq(run.lives, 3, "below the first threshold: nothing")
	run._on_score_changed(10000)
	assert_eq(run.lives, 4, "first extra ship at 10,000 (§4.4)")
	assert_eq(run.bombs, 4, "+1 bomb with the ship (§4.3)")
	run._on_score_changed(59999)
	assert_eq(run.lives, 4, "next threshold is 60,000, not 50,000")
	run._on_score_changed(110000)
	assert_eq(run.lives, 5, "60k and 110k both crossed; capped at 5 (§4.4)")
	assert_eq(run.bombs, 5, "bombs capped at 5 (§4.3)")
	run._on_score_changed(160000)
	assert_eq(run.lives, 5, "cap includes the active ship — never above 5")
	# A threshold crossed at the ship cap awards nothing at all: the §4.3
	# bomb rides only on an actually awarded ship (M3 review finding).
	run.bombs = 2
	run._on_score_changed(210000)
	assert_eq(run.lives, 5, "still capped")
	assert_eq(run.bombs, 2, "no consolation bomb when the ship award is blocked (§4.3/§4.4)")
	_free_session(session)


func test_terrain_lethal_on_pilot_forgiving_on_cadet() -> void:
	var pilot := _spawn_session(784, 1)
	var pilot_world: Node2D = pilot.get_node("World")
	var pilot_run: Node = pilot.get_node("RunController")
	pilot_world.player.position.y = 700.0  # below every valley floor
	pilot_world._physics_process(DT)
	assert_false(pilot_world.player.alive, "terrain contact destroys the ship on Pilot (§4.2)")
	assert_eq(pilot_run.lives, 2, "a life is consumed")
	_free_session(pilot)

	var cadet := _spawn_session(785, 0)
	var cadet_world: Node2D = cadet.get_node("World")
	var cadet_run: Node = cadet.get_node("RunController")
	assert_eq(cadet_run.lives, 5, "Cadet starts with 5 ships (§6.4)")
	assert_eq(cadet_run.bombs, 5, "Cadet starts with 5 bombs (§6.4)")
	cadet_world.player.position.y = 700.0
	cadet_world._physics_process(DT)
	assert_true(cadet_world.player.alive, "Cadet keeps the forgiving rebound (§4.2)")
	_free_session(cadet)
