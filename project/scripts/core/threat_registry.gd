## ThreatRegistry (plan §10.6, §11): normalized contact data for the scanner.
## GameWorld rebuilds it once per physics tick from its entity lists — the
## scanner never searches the scene tree.
##
## Contact shape: { kind: StringName, sim_x: float, sim_y: float }
## kinds: &"player", &"snatcher", &"settler", &"settler_carried",
## &"settler_falling"
class_name ThreatRegistry
extends RefCounted

const Settler := preload("res://scripts/actors/settler.gd")

var contacts: Array[Dictionary] = []


func rebuild(player: Node2D, enemies: Array, settlers: Array) -> void:
	contacts.clear()
	contacts.append({"kind": &"player", "sim_x": player.sim_x, "sim_y": player.position.y})
	for enemy in enemies:
		if enemy.alive:
			contacts.append({"kind": &"snatcher", "sim_x": enemy.sim_x, "sim_y": enemy.sim_y})
	for settler in settlers:
		var kind := &"settler"
		match settler.state:
			Settler.State.LOST, Settler.State.MUTATED:
				continue
			Settler.State.CARRIED_BY_ENEMY, Settler.State.CARRIED_BY_PLAYER:
				kind = &"settler_carried"
			Settler.State.FALLING:
				kind = &"settler_falling"
		contacts.append({"kind": kind, "sim_x": settler.sim_x, "sim_y": settler.sim_y})
