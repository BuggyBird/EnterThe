extends Node
## Verifies room lamps: a decorated room shows the lamp sprites, each lamp casts its
## own PointLight2D whose lit radius is MUCH smaller than the player's torch (it's
## ambient mood light), and the lamp art has a transparent border (no black fringe
## against the tiles).
##   godot --headless --path <proj> res://tests/lamp_light_test.tscn

const LAMP_SCRIPT := preload("res://rooms/decoration/lamp.gd")

var _room: RoomDef
var _player: Player
var _frames := 0


func _ready() -> void:
	RNG.set_seed(1)
	_room = load("res://rooms/combat/combat_cross.tscn").instantiate()
	add_child(_room)
	# A real player so "much smaller than the player's light" is checked against the
	# actual exported radius, not a magic number.
	_player = load("res://actors/player/player.tscn").instantiate()
	add_child(_player)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 4:
		return

	var ok := true
	var lamps: Array = []
	for child in _room.get_children():
		if child.get_script() == LAMP_SCRIPT:
			lamps.append(child)
	if lamps.is_empty():
		ok = false
		print("  no lamps found in combat_cross")

	for lamp in lamps:
		if lamp.texture == null:
			ok = false
			print("  lamp has no sprite texture")
		else:
			# Corner pixel must be transparent — an opaque corner would read as a
			# black/box border on the tiles.
			var img: Image = lamp.texture.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				if img.get_pixel(0, 0).a > 0.02:
					ok = false
					print("  lamp texture corner is not transparent (border risk)")

		var light: PointLight2D = lamp.get_node_or_null("LampLight")
		if light == null:
			ok = false
			print("  lamp has no LampLight PointLight2D")
			continue
		if light.energy <= 0.0:
			ok = false
			print("  lamp light energy is not positive")
		# MIX so lamp + player lights merge in their overlap instead of stacking.
		if light.blend_mode != Light2D.BLEND_MODE_MIX:
			ok = false
			print("  lamp light is not MIX-blended (overlaps would stack)")
		var radius := light.texture_scale * LAMP_SCRIPT.GLOW_TEX_HALF
		if radius <= 0.0:
			ok = false
			print("  lamp glow radius is not positive")
		# "Much smaller": a lamp pool should be well under half the player's torch.
		if radius >= _player.light_radius * 0.5:
			ok = false
			print("  lamp radius %.0f not much smaller than player %.0f" % [
				radius, _player.light_radius])

	print("LAMP LIGHT TEST: %s (%d lamps)" % ["PASS" if ok else "FAIL", lamps.size()])
	get_tree().quit(0 if ok else 1)
