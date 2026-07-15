extends Node
## Headless test for the player's body animations. Run as a SCENE (autoloads on):
##   godot --headless --path <proj> res://tests/player_anim_test.tscn
##
## Verifies:
## (1) The body sprite is an AnimatedSprite2D with idle/walk/dodge animations and
##     starts idling; the body faces the aim side (flip_h when aiming left).
## (2) Holding a move input switches the state machine to Move -> "walk" plays.
## (3) A dodge plays the tumble ("dodge"), mirrors by ROLL direction (not aim),
##     and fades the body for the i-frames.
## (4) After the roll: back to "walk" while still moving, full opacity restored,
##     and releasing input returns to "idle".

var _frames := 0
var _player: Player
var _sprite: AnimatedSprite2D
var _idle_ok := false
var _flip_ok := false
var _walk_ok := false
var _dodge_ok := false
var _after_ok := false
var _rest_ok := false


func _ready() -> void:
	_player = load("res://actors/player/player.tscn").instantiate()
	# Away from the (0,0)-ish headless mouse, so the aim points back left.
	_player.position = Vector2(500, 300)
	add_child(_player)
	_sprite = _player.sprite


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		var frames_ok: bool = _sprite.sprite_frames != null \
			and _sprite.sprite_frames.has_animation(&"idle") \
			and _sprite.sprite_frames.has_animation(&"walk") \
			and _sprite.sprite_frames.has_animation(&"dodge")
		_idle_ok = frames_ok and _sprite.animation == &"idle" and _sprite.is_playing()
		Input.action_press("move_right")
	if _frames == 10:
		_walk_ok = _sprite.animation == &"walk" and _sprite.is_playing()
		# Dodge: feed the action through the active state like real input would.
		var ev := InputEventAction.new()
		ev.action = &"dodge"
		ev.pressed = true
		_player.get_node("StateMachine").current_state.handle_input(ev)
	if _frames == 12:
		# Tumbling right (roll direction), NOT re-flipped left by the aim.
		_dodge_ok = _sprite.animation == &"dodge" \
			and not _sprite.flip_h and _player.modulate.a < 1.0
	if _frames == 35:
		# Roll (0.28s = ~17 frames) is over: still holding right -> walking,
		# fade lifted, aim-facing restored (left again).
		_after_ok = _sprite.animation == &"walk" \
			and _player.modulate == Color.WHITE and _sprite.flip_h
		Input.action_release("move_right")
	if _frames == 45:
		_rest_ok = _sprite.animation == &"idle"
		# Aim (settled by now) points left at the far-away cursor: body faces it.
		_flip_ok = _sprite.flip_h
		var all_ok := _idle_ok and _flip_ok and _walk_ok and _dodge_ok \
			and _after_ok and _rest_ok
		print("PLAYER ANIM TEST: %s (idle=%s flip=%s walk=%s dodge=%s after=%s rest=%s)" % [
			"PASS" if all_ok else "FAIL", _idle_ok, _flip_ok, _walk_ok,
			_dodge_ok, _after_ok, _rest_ok
		])
		get_tree().quit(0 if all_ok else 1)
