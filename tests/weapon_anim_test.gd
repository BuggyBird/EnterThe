extends Node
## Headless test for the held-weapon animations. Run as a SCENE (autoloads on):
##   godot --headless --path <proj> res://tests/weapon_anim_test.tscn
##
## Verifies:
## (1) Data: longbow + repeater carry 3 wind-up frames, bonerang spins on fire,
##     all three have idle sway (the other weapons stay static: idle_sway 0).
## (2) Longbow: mid-channel the held sprite shows a draw frame, near the end of
##     the draw it shows the LAST frame, and it snaps back to the rest sprite
##     after the arrow looses.
## (3) Repeater: a full banked charge shows the last charge frame + the sprite
##     trembles off its base position; releasing reverts to the rest sprite.
## (4) Bonerang: firing kicks the flourish spin, which unwinds back to level.

var _frames := 0
var _player: Player
var _sprite: Sprite2D
var _bow: WeaponData
var _repeater: WeaponData
var _bonerang: WeaponData
var _data_ok := true
var _bow_mid_ok := false
var _bow_full_ok := false
var _bow_rest_ok := false
var _charge_ok := false
var _charge_rest_ok := false
var _spin_ok := false
var _spin_rest_ok := false
var _charge_pos := Vector2.ZERO


func _ready() -> void:
	_bow = load("res://weapons/data/whisperwind_longbow.tres")
	_repeater = load("res://weapons/data/soulwood_repeater.tres")
	_bonerang = load("res://weapons/data/bonerang.tres")

	# (1) The three lively weapons carry animation data; the starter does not.
	_check(_bow.draw_frames.size() == 3, "longbow should have 3 draw frames")
	_check(_repeater.draw_frames.size() == 3, "repeater should have 3 charge frames")
	_check(_bonerang.fire_spin, "bonerang should flourish-spin on fire")
	for data in [_bow, _repeater, _bonerang]:
		_check(data.idle_sway > 0.0, "%s should idle-sway" % data.id)
	var starter: WeaponData = load("res://weapons/data/soul_pistol.tres")
	_check(starter.draw_frames.is_empty() and not starter.fire_spin \
		and starter.idle_sway == 0.0, "soul_pistol must stay animation-free")

	_player = load("res://actors/player/player.tscn").instantiate()
	add_child(_player)
	_sprite = _player.get_node("AimPivot/WeaponSprite")
	# (2) Start a longbow draw (channel_time 0.6s = 36 physics frames).
	_player.weapon_holder.add_weapon(_bow)
	_player.weapon_holder.weapon.try_fire(Vector2.RIGHT, Vector2.ZERO)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_data_ok = false
		print("  " + message)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 15:
		# ~40% drawn: some wind-up frame is showing, but not the rest sprite.
		_bow_mid_ok = _sprite.texture in _bow.draw_frames
	if _frames == 34:
		# ~95% drawn: the LAST frame (full draw) is showing.
		_bow_full_ok = _sprite.texture == _bow.draw_frames[2]
	if _frames == 50:
		# The arrow loosed (36 frames): back to the rest sprite.
		_bow_rest_ok = _sprite.texture == _bow.sprite
		# (3) Bank a full repeater charge.
		_player.weapon_holder.add_weapon(_repeater)
		_player.weapon_holder.weapon.charge(2.0)
	if _frames == 55:
		_charge_ok = _sprite.texture == _repeater.draw_frames[2]
		_charge_pos = _sprite.position
	if _frames == 57:
		# The tremble keeps the strained sprite moving between frames.
		_charge_ok = _charge_ok and _sprite.position != _charge_pos
		_player.weapon_holder.weapon.release_charge(Vector2.RIGHT, Vector2.ZERO)
	if _frames == 90:
		# Salvo done, charge gone: rest sprite again.
		_charge_rest_ok = _sprite.texture == _repeater.sprite
		# (4) Throw the bonerang: the flourish spin kicks in ...
		_player.weapon_holder.add_weapon(_bonerang)
		_player.weapon_holder.weapon.try_fire(Vector2.RIGHT, Vector2.ZERO)
	if _frames == 92:
		_spin_ok = _player._spin > 0.0 and absf(_sprite.rotation) > 0.5
	if _frames == 120:
		# ... and has fully unwound half a second later.
		_spin_rest_ok = is_zero_approx(_player._spin)
		var all_ok := _data_ok and _bow_mid_ok and _bow_full_ok and _bow_rest_ok \
			and _charge_ok and _charge_rest_ok and _spin_ok and _spin_rest_ok
		print("WEAPON ANIM TEST: %s (data=%s bow mid/full/rest=%s/%s/%s charge=%s/%s spin=%s/%s)" % [
			"PASS" if all_ok else "FAIL", _data_ok, _bow_mid_ok, _bow_full_ok,
			_bow_rest_ok, _charge_ok, _charge_rest_ok, _spin_ok, _spin_rest_ok
		])
		get_tree().quit(0 if all_ok else 1)
