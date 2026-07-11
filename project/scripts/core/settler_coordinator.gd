## SettlerCoordinator (plan §4.5, §10.6): the single owner of Settler
## reservations, carriers, and every state transition. No actor may claim a
## Settler or change its state directly — Snatchers request reservations
## here, the world reports catches/deliveries here, and Settlers report
## fall impacts and recovery timers here.
##
## Emits typed domain events; ScoreService and RunController subscribe.
class_name SettlerCoordinator
extends RefCounted

const Settler := preload("res://scripts/actors/settler.gd")

signal settler_targeted(settler: Node2D)
signal settler_taken(settler: Node2D)
signal settler_falling(settler: Node2D)
signal settler_caught(settler: Node2D)
signal settler_delivered(settler: Node2D)
signal settler_landed_safe(settler: Node2D)
signal settler_lost(settler: Node2D)
signal settler_mutated(settler: Node2D)

var settlers: Array = []

## §5/§6.2: cap on simultaneous active abductions (TARGETED + CARRIED_BY_ENEMY).
var abduction_cap := 1

## reservation owner (Snatcher) -> Settler, covering TARGETED and
## CARRIED_BY_ENEMY. One owner per Settler, one Settler per owner.
var _reservations := {}

var _ring: RingWorld
var _balance: Resource  # SettlerBalance


func _init(ring: RingWorld, balance: Resource, p_abduction_cap: int) -> void:
	_ring = ring
	_balance = balance
	abduction_cap = p_abduction_cap


func register_settler(settler: Node2D) -> void:
	settlers.append(settler)
	settler.bind_coordinator(self)


func alive_count() -> int:
	var count := 0
	for settler in settlers:
		if settler.is_alive():
			count += 1
	return count


## True while any abduction/catch transition is unresolved (§6.1 wave-clear
## gate): a Settler airborne or in enemy/player hands blocks wave completion.
func has_unresolved_transitions() -> bool:
	for settler in settlers:
		match settler.state:
			Settler.State.TARGETED, Settler.State.CARRIED_BY_ENEMY, \
			Settler.State.FALLING, Settler.State.CARRIED_BY_PLAYER:
				return true
	return false


func active_abductions() -> int:
	return _reservations.size()


func carried_by_player() -> Array:
	return settlers.filter(func(s): return s.state == Settler.State.CARRIED_BY_PLAYER)


## A Snatcher asks for the nearest available Settler (§4.5: shortest wrapped
## distance). Returns null when the abduction cap is reached or no Settler is
## targetable. On success the Settler is reserved (TARGETED) for this owner.
func try_reserve(owner: Object, from_x: float) -> Node2D:
	if _reservations.has(owner):
		return _reservations[owner]
	if active_abductions() >= abduction_cap:
		return null
	var best: Node2D = null
	var best_distance := INF
	for settler in settlers:
		if settler.state != Settler.State.SAFE:
			continue
		var distance: float = _ring.wrapped_distance_x(from_x, settler.sim_x)
		if distance < best_distance:
			best_distance = distance
			best = settler
	if best == null:
		return null
	_reservations[owner] = best
	best.apply_state(Settler.State.TARGETED)
	settler_targeted.emit(best)
	return best


## Owner gives up a reservation that hasn't reached the grab (TARGETED only).
func release_reservation(owner: Object) -> void:
	var settler: Node2D = _reservations.get(owner)
	if settler == null:
		return
	_reservations.erase(owner)
	if settler.state == Settler.State.TARGETED:
		settler.apply_state(Settler.State.SAFE)


## The reserving Snatcher completed the grab.
func begin_carry(owner: Object) -> void:
	var settler: Node2D = _reservations.get(owner)
	if settler == null or settler.state != Settler.State.TARGETED:
		return
	settler.apply_state(Settler.State.CARRIED_BY_ENEMY)
	settler_taken.emit(settler)


## The carrying/reserving Snatcher was destroyed (§4.5: a carried Settler is
## released into FALLING).
func carrier_destroyed(owner: Object) -> void:
	var settler: Node2D = _reservations.get(owner)
	if settler == null:
		return
	_reservations.erase(owner)
	match settler.state:
		Settler.State.TARGETED:
			settler.apply_state(Settler.State.SAFE)
		Settler.State.CARRIED_BY_ENEMY:
			settler.apply_state(Settler.State.FALLING)
			settler_falling.emit(settler)


## The carrying Snatcher reached the escape boundary (§4.5): the Settler is
## removed as MUTATED (and is responsible for a transformed enemy — the
## Ravager spawn arrives with the Milestone 4 roster).
func carrier_escaped(owner: Object) -> void:
	var settler: Node2D = _reservations.get(owner)
	if settler == null or settler.state != Settler.State.CARRIED_BY_ENEMY:
		return
	_reservations.erase(owner)
	settler.apply_state(Settler.State.MUTATED)
	settler_mutated.emit(settler)


## The player caught a falling Settler by overlap (§4.5).
func catch_settler(settler: Node2D) -> void:
	if settler.state != Settler.State.FALLING:
		return
	settler.apply_state(Settler.State.CARRIED_BY_PLAYER)
	settler_caught.emit(settler)


## The player entered the safe drop band: the Settler returns to the surface
## in the brief protected DELIVERED state (§4.5).
func deliver_settler(settler: Node2D, ground_y: float) -> void:
	if settler.state != Settler.State.CARRIED_BY_PLAYER:
		return
	settler.sim_y = ground_y
	settler.apply_state(Settler.State.DELIVERED)
	settler_delivered.emit(settler)


## Reported by the Settler when a fall reaches the surface (§4.5:
## low-altitude falls survive; higher impacts cause LOST).
func ground_impact(settler: Node2D, fall_distance: float) -> void:
	if settler.state != Settler.State.FALLING:
		return
	if fall_distance > _balance.safe_fall_distance:
		settler.apply_state(Settler.State.LOST)
		settler_lost.emit(settler)
	else:
		settler.apply_state(Settler.State.SAFE)
		settler_landed_safe.emit(settler)


## Reported by the Settler when its DELIVERED protection timer ends.
func delivered_recovered(settler: Node2D) -> void:
	if settler.state == Settler.State.DELIVERED:
		settler.apply_state(Settler.State.SAFE)
