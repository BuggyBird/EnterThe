extends Node
## Verifies the dungeon light system: the world is dimmed by a CanvasModulate, the
## player carries a PointLight2D whose lit radius tracks its `light_radius` export,
## and changing that radius at runtime resizes the light.
##   godot --headless --path <proj> res://tests/light_system_test.tscn

var _dungeon: Node2D
var _frames := 0


func _ready() -> void:
	RNG.set_seed(1)
	_dungeon = load("res://procgen/dungeon.tscn").instantiate()
	add_child(_dungeon)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 5:
		return

	var ok := true

	# 1. A CanvasModulate dims the world, and it's actually dark.
	var cm: CanvasModulate = _dungeon.get_node_or_null("Darkness")
	if cm == null:
		ok = false
		print("  no Darkness CanvasModulate on the dungeon")
	else:
		var lum := cm.color.r * 0.3 + cm.color.g * 0.59 + cm.color.b * 0.11
		if lum >= 0.5:
			ok = false
			print("  ambient not dark: luminance %.2f" % lum)

	# 2. The player owns a PointLight2D with a real texture and positive energy.
	var player: Player = _dungeon._player
	var light: PointLight2D = player.get_node_or_null("PlayerLight") if player else null
	if light == null:
		ok = false
		print("  player has no PlayerLight PointLight2D")
	else:
		if light.texture == null:
			ok = false
			print("  player light has no texture")
		if light.energy <= 0.0:
			ok = false
			print("  player light energy is not positive")
		# MIX so it unions with other lights (overlaps merge, not stack).
		if light.blend_mode != Light2D.BLEND_MODE_MIX:
			ok = false
			print("  player light is not MIX-blended (overlaps would stack)")

		# 3. The lit radius matches light_radius (within the flicker margin).
		var expected := player.light_radius / Player.LIGHT_TEX_HALF
		var margin := player.light_flicker + 0.02
		if absf(light.texture_scale - expected) > expected * margin:
			ok = false
			print("  scale %.3f doesn't match radius %.0f (expected ~%.3f)" % [
				light.texture_scale, player.light_radius, expected])

		# 4. Changing the radius at runtime resizes the light next update.
		var before := light.texture_scale
		player.set_light_radius(player.light_radius * 2.0)
		player._update_light(0.0)
		if light.texture_scale <= before * 1.5:
			ok = false
			print("  doubling radius did not grow the light (%.3f -> %.3f)" % [
				before, light.texture_scale])

	print("LIGHT SYSTEM TEST: %s" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
