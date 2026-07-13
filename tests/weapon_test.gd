extends Node
## Headless automated test for the weapon system. Run as a SCENE (autoloads on):
##   godot --headless --path <proj> res://tests/weapon_test.tscn
##
## Verifies: (1) the player starts equipped with the Soul Pistol, (2) firing
## consumes a clip round and spawns a projectile, (3) picking up a new weapon
## adds it and auto-equips it.

var _frames := 0
var _fire_ok := false
var _spawn_ok := false
var _pickup_ok := false


func _ready() -> void:
	var player: Node = load("res://actors/player/player.tscn").instantiate()
	add_child(player)
	var holder = player.get_node("WeaponHolder")

	# (1)/(2) Firing the starter weapon.
	var clip_before: int = holder.weapon.clip
	var starter_id = holder.get_current_data().id
	holder.try_fire(Vector2.RIGHT, Vector2.ZERO)
	_fire_ok = starter_id == &"soul_pistol" and holder.weapon.clip == clip_before - 1
	_spawn_ok = _count_projectiles() >= 1

	# (3) Picking up a different weapon auto-equips it.
	holder.add_weapon(load("res://weapons/data/gravedigger.tres"))
	_pickup_ok = holder.get_current_data().id == &"gravedigger"


func _count_projectiles() -> int:
	var count := 0
	for child in get_tree().current_scene.get_children():
		if child is Projectile:
			count += 1
	return count


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= 3:
		var all_ok := _fire_ok and _spawn_ok and _pickup_ok
		print("WEAPON TEST: %s (fire=%s spawn=%s pickup=%s)" % [
			"PASS" if all_ok else "FAIL", _fire_ok, _spawn_ok, _pickup_ok
		])
		get_tree().quit(0 if all_ok else 1)
