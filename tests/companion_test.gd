extends Node
## Headless automated test for the companion pup. Run as a SCENE (autoloads on):
##   godot --headless --path <proj> res://tests/companion_test.tscn
##
## Verifies the pup exists inside the player scene, plays his idle animation,
## and drifts after the player when they move across the room.

var _frames := 0
var _player: Player
var _dog: CompanionDog
var _setup_ok := false


func _ready() -> void:
	_player = load("res://actors/player/player.tscn").instantiate()
	add_child(_player)
	_dog = _player.get_node_or_null("Companion")
	_setup_ok = _dog != null and _dog.animation == &"idle" and _dog.is_playing()
	# Send the player far across the room; the pup should chase.
	_player.global_position = Vector2(400, 120)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= 80:
		var followed := false
		if _dog != null:
			# After ~1.3s of easing he should be hovering near his offset
			# point beside the player — mirrored opposite the aim, like the
			# pup computes it (bob and trailing allow some slack).
			var side := 1.0 if _player.aim_direction.x < 0.0 else -1.0
			var hover := _player.global_position + Vector2(36.0 * side, -30)
			followed = _dog.global_position.distance_to(hover) < 40.0
		print("COMPANION TEST: %s (setup=%s followed=%s dog=%s player=%s)" % [
			"PASS" if _setup_ok and followed else "FAIL", _setup_ok, followed,
			_dog.global_position if _dog else Vector2.INF, _player.global_position
		])
		get_tree().quit(0 if _setup_ok and followed else 1)
