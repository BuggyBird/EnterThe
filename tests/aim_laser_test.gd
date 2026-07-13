extends Node
## Verifies the aim laser: a Line2D from the muzzle toward the aim direction that
## is cut short by wall collision (RayCast2D on the World layer), and runs to full
## length when nothing blocks it.
##   godot --headless --path <proj> res://tests/aim_laser_test.tscn

var _player: Player
var _frames := 0


func _ready() -> void:
	_player = load("res://actors/player/player.tscn").instantiate()
	add_child(_player)
	_player.global_position = Vector2.ZERO

	# A wall 200px to the player's right (World layer 1), left face at x=180.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(200, 0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	cs.shape = rect
	wall.add_child(cs)
	add_child(wall)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 3:
		return

	var line: Line2D = _player.get_node("AimPivot/AimLine")
	var ok := true

	# Aim right, into the wall: laser should stop near the wall face (~180), not 2000.
	_player.aim_pivot.rotation = 0.0
	_player.update_aim_line()
	var blocked_end: float = line.points[1].x
	if not (absf(blocked_end - 180.0) < 6.0):
		ok = false
		print("  blocked laser end = %.1f, expected ~180" % blocked_end)

	# Aim up, into open space: laser should reach full ray length.
	_player.aim_pivot.rotation = -PI * 0.5
	_player.update_aim_line()
	var open_end: float = line.points[1].x
	if open_end < 1500.0:
		ok = false
		print("  open laser end = %.1f, expected ~2000" % open_end)

	# Line starts at the muzzle, not the player center.
	if not is_equal_approx(line.points[0].x, _player.muzzle.position.x):
		ok = false
		print("  laser start = %.1f, expected muzzle %.1f" % [line.points[0].x, _player.muzzle.position.x])

	print("AIM LASER TEST: %s" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
