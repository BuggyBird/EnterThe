extends Node
## Verifies the wall torches: every room grows torches along its top wall, each
## one is a 32x32 animated sprite with its own SMALL, DIM, MIX-blended light
## (mood lighting layered under the dark ambient — never a bright hotspot),
## torches keep clear of the doorways, and the player's own light is dimmer
## than it used to be (radius under 200, energy under 1.0).
##   godot --headless --path <proj> res://tests/torch_light_test.tscn

const TORCH_SCRIPT := preload("res://rooms/decoration/torch.gd")

var _room: RoomDef
var _player: Player
var _frames := 0


func _ready() -> void:
	RNG.set_seed(1)
	_room = load("res://rooms/combat/combat_cross.tscn").instantiate()
	add_child(_room)
	_player = load("res://actors/player/player.tscn").instantiate()
	_player.position = Vector2(600, 600)   # out of the way
	add_child(_player)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 4:
		return

	var ok := true
	var torches: Array = []
	for child in _room.get_children():
		if child.get_script() == TORCH_SCRIPT:
			torches.append(child)
	if torches.is_empty():
		ok = false
		print("  no torches mounted in combat_cross")

	for torch in torches:
		# 32x32 animated flame.
		var tex: Texture2D = torch.sprite_frames.get_frame_texture(&"burn", 0)
		if tex == null or tex.get_size() != Vector2(32, 32):
			ok = false
			print("  torch frame is not 32x32")
		if torch.sprite_frames.get_frame_count(&"burn") < 2:
			ok = false
			print("  torch flame is not animated")

		# On the TOP wall (above the room centre) and clear of the doorways.
		if torch.position.y > -_room.room_size.y * 0.25:
			ok = false
			print("  torch not on the top wall (y=%.0f)" % torch.position.y)
		for door in _room.get_exits():
			if door["dir"] == Vector2i.UP \
					and absf((door["pos"] as Vector2).x - torch.position.x) < RoomDef.DOOR_WIDTH * 0.5:
				ok = false
				print("  torch overlaps a top doorway (x=%.0f)" % torch.position.x)

		var light: PointLight2D = torch.get_node_or_null("TorchLight")
		if light == null:
			ok = false
			print("  torch has no TorchLight PointLight2D")
			continue
		if light.blend_mode != Light2D.BLEND_MODE_MIX:
			ok = false
			print("  torch light is not MIX-blended (overlaps would stack)")
		# DIM: noticeably fainter and smaller than the player's own light.
		if light.energy <= 0.0 or light.energy >= 0.8:
			ok = false
			print("  torch energy %.2f is not in the dim range (0, 0.8)" % light.energy)
		var radius: float = light.texture_scale * TORCH_SCRIPT.GLOW_TEX_HALF
		if radius <= 0.0 or radius >= _player.light_radius * 0.5:
			ok = false
			print("  torch radius %.0f not much smaller than player %.0f" % [
				radius, _player.light_radius])

	# The player's light itself was dimmed: working vision, not a floodlight.
	if _player.light_radius >= 200.0 or _player.light_energy >= 1.0:
		ok = false
		print("  player light not dimmed (radius=%.0f energy=%.2f)" % [
			_player.light_radius, _player.light_energy])

	print("TORCH LIGHT TEST: %s (%d torches)" % ["PASS" if ok else "FAIL", torches.size()])
	get_tree().quit(0 if ok else 1)
