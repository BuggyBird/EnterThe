extends Node
## Verifies weapons carry an in-hand sprite and the player shows it: the held
## WeaponSprite gets the equipped weapon's texture + color tint, updates on switch,
## and flips upright when aiming left.
##   godot --headless --path <proj> res://tests/weapon_sprite_test.tscn

func _ready() -> void:
	var ok := true

	# Every weapon .tres should now carry a sprite.
	for path in ["soul_pistol", "gravedigger", "wisp", "bone_railbolt"]:
		var data: WeaponData = load("res://weapons/data/%s.tres" % path)
		if data.sprite == null:
			ok = false
			print("  %s has no sprite" % path)

	var player: Player = load("res://actors/player/player.tscn").instantiate()
	add_child(player)
	var sprite: Sprite2D = player.get_node("AimPivot/WeaponSprite")
	var starter: WeaponData = player.weapon_holder.get_current_data()

	# Initial equip synced the held sprite (signal fired before player connected).
	if sprite.texture != starter.sprite:
		ok = false
		print("  held sprite texture not set from starter weapon")
	if sprite.modulate != starter.color:
		ok = false
		print("  held sprite tint != weapon color")
	if not sprite.visible:
		ok = false
		print("  held sprite not visible")

	# sprite_scale from the .tres multiplies the scene's base scale.
	var base := player._base_weapon_scale
	if not sprite.scale.is_equal_approx(base * starter.sprite_scale):
		ok = false
		print("  scale not applied: got %s expected %s" % [sprite.scale, base * starter.sprite_scale])

	# Aiming left flips the weapon upright; aiming right does not.
	player.aim_pivot.rotation = PI          # left
	player.update_weapon_flip()
	var flipped_left := sprite.flip_v
	player.aim_pivot.rotation = 0.0         # right
	player.update_weapon_flip()
	var flat_right := not sprite.flip_v
	if not (flipped_left and flat_right):
		ok = false
		print("  flip_v wrong: left=%s right=%s" % [flipped_left, sprite.flip_v])

	print("WEAPON SPRITE TEST: %s" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
