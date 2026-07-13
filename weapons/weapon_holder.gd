class_name WeaponHolder
extends Node2D
## The player's weapon inventory. Carries several WeaponData, tracks per-weapon
## ammo, and drives a single child Weapon node to fire the equipped one. Handles
## switching and acquiring new weapons from pickups.
##
## Per-weapon ammo lives here (in Slot objects), NOT in the shared WeaponData
## resource — otherwise all copies/instances would share ammo.

## One owned weapon plus its live ammo state.
class Slot:
	var data: WeaponData
	var clip: int
	var reserve: int

	func _init(weapon_data: WeaponData) -> void:
		data = weapon_data
		clip = weapon_data.mag_size
		reserve = weapon_data.max_reserve


## Weapons the player starts with (first one is equipped).
@export var starting_weapons: Array[WeaponData] = []

@onready var weapon: Weapon = $Weapon

var _slots: Array[Slot] = []
var _index: int = 0


func _ready() -> void:
	for weapon_data in starting_weapons:
		if weapon_data:
			_slots.append(Slot.new(weapon_data))
	if not _slots.is_empty():
		_equip(0)


## Forwarded from the player each frame the fire input is held/pressed.
func try_fire(aim_direction: Vector2, origin: Vector2) -> void:
	weapon.try_fire(aim_direction, origin)


func reload() -> void:
	weapon.start_reload()


func get_current_data() -> WeaponData:
	return _slots[_index].data if _index < _slots.size() else null


## Every owned weapon's data, in acquisition order (for the inventory screen).
func get_owned_weapons() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for slot in _slots:
		out.append(slot.data)
	return out


## Index of the currently equipped weapon within get_owned_weapons().
func get_equipped_index() -> int:
	return _index


func next_weapon() -> void:
	if _slots.size() > 1:
		_equip((_index + 1) % _slots.size())


func prev_weapon() -> void:
	if _slots.size() > 1:
		_equip((_index - 1 + _slots.size()) % _slots.size())


## Acquire a weapon from a pickup. If already owned, top up its reserve instead
## of adding a duplicate; otherwise add it and auto-equip.
func add_weapon(weapon_data: WeaponData) -> void:
	if weapon_data == null:
		return
	for slot in _slots:
		if slot.data.id == weapon_data.id:
			if slot.reserve >= 0:
				slot.reserve += weapon_data.mag_size
			_sync_equipped_ammo()
			return
	_slots.append(Slot.new(weapon_data))
	EventBus.weapon_added.emit(weapon_data)
	_equip(_slots.size() - 1)


## Switch to slot `i`, saving the current weapon's ammo back to its slot first.
func _equip(i: int) -> void:
	if _index < _slots.size() and weapon.data != null:
		_slots[_index].clip = weapon.clip
		_slots[_index].reserve = weapon.reserve
	_index = i
	var slot := _slots[i]
	weapon.equip(slot.data, slot.clip, slot.reserve)
	EventBus.weapon_equipped.emit(slot.data)


## Push the equipped weapon's slot ammo into the live Weapon (used after a
## same-weapon pickup tops up reserve).
func _sync_equipped_ammo() -> void:
	var slot := _slots[_index]
	weapon.reserve = slot.reserve
	weapon._emit_ammo()
