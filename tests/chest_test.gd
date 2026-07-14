extends Node
## Headless automated test for the gold + chest loop. Run as a SCENE:
##   godot --headless --path <proj> res://tests/chest_test.tscn
##
## Verifies: (1) a dying enemy bursts into coins, (2) a coin touching the
## player pays into GameState.gold, (3) a chest refuses to open when gold is
## short, (4) with enough gold it charges the price, plays its opening
## animation and spawns a weapon pickup.

var _frames := 0
var _drop_ok := false
var _collect_ok := false
var _deny_ok := false
var _chest: Chest
var _gold_after_open := -1


func _ready() -> void:
	GameState.reset_gold()

	# (1) Enemy death -> coins scatter at the death spot. The spawn is DEFERRED
	# (coins appear next idle frame), so we verify the drop in _physics_process.
	var dummy: Node2D = load("res://actors/enemies/dummy/dummy.tscn").instantiate()
	dummy.position = Vector2(600, 600)   # far corner, away from the player
	add_child(dummy)
	dummy.get_node("Health").take_damage(DamageInfo.new(999.0, self, Vector2.ZERO))

	# (2) A coin on top of the player is collected on contact.
	var player: Player = load("res://actors/player/player.tscn").instantiate()
	player.position = Vector2.ZERO
	add_child(player)
	var coin: Node2D = load("res://items/coin/coin.tscn").instantiate()
	add_child(coin)
	coin.global_position = player.global_position

	# (3)/(4) A mythic chest (160 g) with fixed loot.
	_chest = load("res://items/chest/chest.tscn").instantiate()
	_chest.rarity = 4
	_chest.loot = load("res://weapons/data/bonerang.tres")
	_chest.position = Vector2(200, 0)
	add_child(_chest)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 3:
		# The deferred coin burst has landed at the corpse (near 600,600).
		# Count & clear only those, leaving the collect-coin at the origin.
		var far_coins := []
		for c in _coins():
			if c.global_position.distance_to(Vector2(600, 600)) < 60.0:
				far_coins.append(c)
		_drop_ok = far_coins.size() >= GameState.COINS_PER_KILL_MIN
		for c in far_coins:
			c.queue_free()
	if _frames == 10:
		# Coin contact has resolved by now.
		_collect_ok = GameState.gold >= 5
		# (3) Can't afford 160 g -> stays closed, gold untouched.
		var before := GameState.gold
		_deny_ok = not _chest.try_open() and GameState.gold == before \
			and _chest.anim.animation == &"mythic_closed"
		# (4) Fund the purse and open for real.
		GameState.add_gold(200)
		var paid := GameState.gold
		if _chest.try_open():
			_gold_after_open = GameState.gold
			_deny_ok = _deny_ok and _gold_after_open == paid - _chest.cost()
	if _frames >= 90:
		# Opening animation (6 frames @ 10 fps) has finished -> loot pickup out.
		var pickup_out := false
		for child in get_children():
			if child is WeaponPickup:
				pickup_out = child.weapon_data != null
		var open_ok := _gold_after_open >= 0 and _chest.anim.animation == &"mythic_open" \
			and not _chest.anim.is_playing() and pickup_out
		var all_ok := _drop_ok and _collect_ok and _deny_ok and open_ok
		print("CHEST TEST: %s (drop=%s collect=%s deny=%s open=%s gold=%d)" % [
			"PASS" if all_ok else "FAIL", _drop_ok, _collect_ok, _deny_ok, open_ok,
			GameState.gold
		])
		get_tree().quit(0 if all_ok else 1)


func _coins() -> Array:
	var out := []
	for child in get_children():
		if child is Coin:
			out.append(child)
	return out
