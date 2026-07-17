extends Node
## Headless automated test for the rat walk/shoot animations. Run as a SCENE:
##   godot --headless --path <proj> res://tests/rat_anim_test.tscn
##
## Verifies: (1) the shared RatFrames slice the sheet into a 10-frame looping
## walk, a 5-frame non-looping shoot and an idle, all 64x64 cells, (2) a live
## monster actually PLAYS walk during its move bursts and shoot while it
## telegraphs (observed over a few seconds of real AI), (3) the dummy uses the
## same animated sprite.

var _frames := 0
var _monster: Monster
var _seen := {}   # animation name -> true, sampled every physics frame
var _shoot_speed := -1.0   # speed_scale observed while the shoot anim played
var _speed_reset_ok := false   # back to 1.0 once the shot beat is over


func _ready() -> void:
	RNG.set_seed(7)
	var player: Player = load("res://actors/player/player.tscn").instantiate()
	player.position = Vector2.ZERO
	add_child(player)
	_monster = load("res://actors/enemies/monster.tscn").instantiate()
	_monster.data = load("res://resources/monsters/rat_gunner.tres")
	_monster.position = Vector2(420, 0)
	add_child(_monster)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if is_instance_valid(_monster) and _monster.sprite.is_playing():
		_seen[_monster.sprite.animation] = true
		if _monster.sprite.animation == &"shoot":
			_shoot_speed = _monster.sprite.speed_scale
		elif _shoot_speed > 0.0 and is_equal_approx(_monster.sprite.speed_scale, 1.0):
			_speed_reset_ok = true
	if _frames < 300 and not (_seen.size() >= 3 and _speed_reset_ok):
		return

	var ok := true

	# (1) The sliced animation set.
	var frames := RatFrames.frames()
	if frames.get_frame_count(&"walk") != 10 or not frames.get_animation_loop(&"walk"):
		ok = false
		print("  walk should be a 10-frame loop")
	if frames.get_frame_count(&"shoot") != 5 or frames.get_animation_loop(&"shoot"):
		ok = false
		print("  shoot should be 5 frames, non-looping")
	if frames.get_frame_count(&"idle") < 2:
		ok = false
		print("  idle should be animated (2+ frames)")
	for anim in [&"walk", &"shoot", &"idle"]:
		for i in frames.get_frame_count(anim):
			if frames.get_frame_texture(anim, i).get_size() != Vector2(64, 64):
				ok = false
				print("  %s frame %d is not a 64x64 cell" % [anim, i])

	# (2) The AI drove both requested animations.
	if not _seen.has(&"walk"):
		ok = false
		print("  monster never played its walk animation")
	if not _seen.has(&"shoot"):
		ok = false
		print("  monster never played its shoot animation")

	# (2b) No frozen mid-air lunge: the shoot anim is timed to the windup (its
	# last frame lands as the shot fires), and the speed resets afterwards.
	var expected_speed: float = (frames.get_frame_count(&"shoot") \
		/ frames.get_animation_speed(&"shoot")) / _monster.data.windup_time
	if _shoot_speed < 0.0 or absf(_shoot_speed - expected_speed) > 0.01:
		ok = false
		print("  shoot speed_scale %.2f != windup-matched %.2f" % [
			_shoot_speed, expected_speed])
	if not _speed_reset_ok:
		ok = false
		print("  speed_scale did not reset to 1.0 after the shot")

	# (3) The dummy shares the same animated sprite.
	var dummy: Node2D = load("res://actors/enemies/dummy/dummy.tscn").instantiate()
	add_child(dummy)
	var dummy_sprite: AnimatedSprite2D = dummy.get_node("Sprite")
	if dummy_sprite.sprite_frames != frames or not dummy_sprite.is_playing():
		ok = false
		print("  dummy is not playing the shared rat frames")

	print("RAT ANIM TEST: %s (seen=%s after %d frames)" % [
		"PASS" if ok else "FAIL", _seen.keys(), _frames])
	get_tree().quit(0 if ok else 1)
