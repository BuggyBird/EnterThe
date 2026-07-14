extends Node
## Headless automated test for the three "funny weapon" mechanics. Run as a
## SCENE (autoloads on):
##   godot --headless --path <proj> res://tests/funny_weapons_test.tscn
##
## Verifies:
## (1) Bonerang hit combo: throw 1 curves LEFT; a miss repeats the same throw;
##     each LANDED hit advances the cycle left -> right -> both hands -> wraps.
## (2) Whisperwind Longbow: an arrow that travels farther deals more damage
##     (near hit ~2x base, far hit capped at 3x base).
## (3) Soulwood Repeater: holding banks up to 7 bolts; release fires them as a
##     rapid salvo one after another, each paid from the clip.

var _frames := 0
var _combo_ok := false
var _dual_pair: Array[Projectile] = []
var _curve_ok := false
var _pre_salvo_ids := {}
var _salvo_weapon: Weapon
var _salvo_ok := false
var _near_damage := -1.0
var _far_damage := -1.0
var _pre_channel_ids := {}
var _channel_ok := false
var _channel_check_frame := 0
var _arrow_base := 10.0
var _arrow_cap := 3.0


func _ready() -> void:
	var weapon := Weapon.new()
	add_child(weapon)
	_salvo_weapon = weapon

	# (1) Bonerang combo. Hits are simulated by emitting the projectile's
	# hit_landed signal (what a real hurtbox hit fires exactly once).
	weapon.equip(load("res://weapons/data/bonerang.tres"), 30, 30)
	var t1 := _fire(weapon)                       # stage 0
	var t2 := _fire(weapon)                       # missed: stage repeats
	var s1_ok := t1.size() == 1 and t1[0].curve_sign == -1.0 \
		and t2.size() == 1 and t2[0].curve_sign == -1.0
	t2[0].hit_landed.emit()                       # hit -> stage 1
	var t3 := _fire(weapon)
	var s2_ok := t3.size() == 1 and t3[0].curve_sign == 1.0
	t3[0].hit_landed.emit()                       # hit -> stage 2
	var t4 := _fire(weapon)                       # both hands: outward, curving in
	var s3_ok := t4.size() == 2 and t4[0].curve_sign * t4[1].curve_sign < 0.0
	for p in t4:
		# Each launches angled OUTWARD (~40 deg) on the opposite side of its
		# curve, so the pair closes back across the aim line like pincers.
		s3_ok = s3_ok and p.curve_sign * p.direction.y < 0.0 and absf(p.direction.y) > 0.5
	_dual_pair = t4
	t4[0].hit_landed.emit()
	t4[1].hit_landed.emit()                       # 4 hits -> stage 4 % 3 = 1 (right)
	var t5 := _fire(weapon)
	_combo_ok = s1_ok and s2_ok and s3_ok and t5.size() == 1 and t5[0].curve_sign == 1.0

	# (2) Longbow arrows: near dummy (300 px) vs far dummy (1200 px, past the
	# 3x cap). Damage recorded via the Health `damaged` signal.
	var arrow_data: ProjectileData = load("res://projectiles/data/spectral_arrow.tres")
	_arrow_base = arrow_data.damage
	_arrow_cap = arrow_data.distance_damage_max_mult
	var near_dummy := _spawn_dummy(Vector2(300, 200))
	var far_dummy := _spawn_dummy(Vector2(1200, 400))
	# First hit only: the arrow lands first; a stray combo boomerang looping
	# through later (possible with wide curve tunings) must not overwrite it.
	near_dummy.get_node("Health").damaged.connect(func(info):
		if _near_damage < 0.0: _near_damage = info.amount)
	far_dummy.get_node("Health").damaged.connect(func(info):
		if _far_damage < 0.0: _far_damage = info.amount)
	_spawn_arrow(arrow_data, Vector2(0, 200))
	_spawn_arrow(arrow_data, Vector2(0, 400))

	# (3) Soulwood Repeater: bank the full 7 (2.0s held / 0.25s per shot > 6
	# extra). Snapshot AFTER the arrows so only salvo bolts count as new.
	weapon.equip(load("res://weapons/data/soulwood_repeater.tres"), 12, 48)
	weapon.charge(2.0)
	var banked: int = weapon.charged_shots()
	for p in _projectiles():
		_pre_salvo_ids[p.get_instance_id()] = true
	weapon.release_charge(Vector2.RIGHT, Vector2.ZERO)
	_salvo_ok = banked == 7  # remaining checks once the burst finishes


## Fire once (cooldown ignored) and return the projectiles this throw spawned.
func _fire(weapon: Weapon) -> Array[Projectile]:
	var before := _projectiles()
	weapon._cooldown = 0.0
	weapon.try_fire(Vector2.RIGHT, Vector2.ZERO)
	var thrown: Array[Projectile] = []
	for p in _projectiles():
		if not before.has(p):
			thrown.append(p)
	return thrown


func _new_since(ids: Dictionary) -> int:
	var count := 0
	for p in _projectiles():
		if not ids.has(p.get_instance_id()):
			count += 1
	return count


func _projectiles() -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in get_children():
		if child is Projectile:
			out.append(child)
	return out


func _spawn_dummy(at: Vector2) -> Node2D:
	var dummy: Node2D = load("res://actors/enemies/dummy/dummy.tscn").instantiate()
	dummy.position = at
	add_child(dummy)
	return dummy


func _spawn_arrow(data: ProjectileData, from: Vector2) -> void:
	var arrow: Projectile = load("res://projectiles/projectile.tscn").instantiate()
	arrow.setup(data, Vector2.RIGHT, from)
	add_child(arrow)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 40:
		# The dual throw's pair, launched along +x, should have peeled apart.
		if _dual_pair.size() == 2 and is_instance_valid(_dual_pair[0]) \
				and is_instance_valid(_dual_pair[1]):
			var ya: float = _dual_pair[0].direction.y
			var yb: float = _dual_pair[1].direction.y
			_curve_ok = ya * yb < 0.0 and absf(ya) > 0.3 and absf(yb) > 0.3
	if _frames == 60:
		# Salvo (first bolt + 6 at 0.07s gaps ~ 26 frames) is long done: exactly
		# 7 new projectiles were fired, each paid from the clip.
		var new_bolts := 0
		for p in _projectiles():
			if not _pre_salvo_ids.has(p.get_instance_id()):
				new_bolts += 1
		_salvo_ok = _salvo_ok and new_bolts == 7 and _salvo_weapon.clip == 5 \
			and _salvo_weapon._burst_left == 0
	if _frames == 65:
		# Longbow channel: firing starts a draw instead of an instant shot.
		var bow: WeaponData = load("res://weapons/data/whisperwind_longbow.tres")
		_channel_check_frame = 65 + int(ceil(bow.channel_time * 60.0)) + 10
		_salvo_weapon.equip(bow, 8, 40)
		for p in _projectiles():
			_pre_channel_ids[p.get_instance_id()] = true
		_salvo_weapon.try_fire(Vector2.RIGHT, Vector2.ZERO)
		_channel_ok = _salvo_weapon._channeling and _salvo_weapon.clip == 8 \
			and _new_since(_pre_channel_ids) == 0
	if _frames == _channel_check_frame:
		# The draw has elapsed: exactly one arrow loosed, paying ammo.
		_channel_ok = _channel_ok and not _salvo_weapon._channeling \
			and _new_since(_pre_channel_ids) == 1 and _salvo_weapon.clip == 7
	if _frames >= _channel_check_frame + 10 and _frames >= 130:
		# Near hit travelled ~300 px (~2x base); far hit is past the cap.
		var near_ok := _near_damage > _arrow_base * 1.7 and _near_damage < _arrow_base * 2.3
		var far_ok := absf(_far_damage - _arrow_base * _arrow_cap) < 0.75
		var distance_ok := near_ok and far_ok and _far_damage > _near_damage
		var all_ok := _combo_ok and _curve_ok and distance_ok and _salvo_ok and _channel_ok
		print("FUNNY WEAPONS TEST: %s (combo=%s curve=%s longbow=%s [near=%.1f far=%.1f] salvo=%s channel=%s)" % [
			"PASS" if all_ok else "FAIL", _combo_ok, _curve_ok, distance_ok,
			_near_damage, _far_damage, _salvo_ok, _channel_ok
		])
		get_tree().quit(0 if all_ok else 1)
