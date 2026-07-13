extends Node
## Verifies the muzzle/aim indicator orbits the PLAYER CENTRE in a circle (never
## sweeping inside the body). Rotates the aim pivot through several angles and
## asserts the muzzle stays at a constant radius and lands in the aimed direction.
##   godot --headless --path <proj> res://tests/aim_orbit_test.tscn

func _ready() -> void:
	var player: Player = load("res://actors/player/player.tscn").instantiate()
	add_child(player)
	player.global_position = Vector2(500, 300)  # off-origin: catches center-vs-pivot bugs

	var pivot: Node2D = player.get_node("AimPivot")
	var muzzle: Marker2D = player.get_node("AimPivot/Muzzle")

	var radius := muzzle.position.length()   # expected orbit radius (local muzzle offset)
	var ok := true
	var body_radius := 16.0

	for deg in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0]:
		var ang := deg_to_rad(deg)
		pivot.rotation = ang
		var offset := muzzle.global_position - player.global_position
		var r := offset.length()
		var dir_ok := offset.normalized().dot(Vector2.RIGHT.rotated(ang)) > 0.999
		var radius_ok := absf(r - radius) < 0.01
		var outside_body := r > body_radius
		if not (dir_ok and radius_ok and outside_body):
			ok = false
			print("  FAIL @ %d deg: r=%.1f expected=%.1f dir_ok=%s outside=%s" % [
				int(deg), r, radius, dir_ok, outside_body])

	print("AIM ORBIT TEST: %s (radius=%.1f)" % ["PASS" if ok else "FAIL", radius])
	get_tree().quit(0 if ok else 1)
