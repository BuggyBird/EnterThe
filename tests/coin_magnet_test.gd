extends Node
## Headless automated test for the coin pickup magnet. Run as a SCENE:
##   godot --headless --path <proj> res://tests/coin_magnet_test.tscn
##
## Verifies: (1) a coin inside the base pull radius homes onto the player and
## is collected, (2) a coin outside the radius stays where it fell, (3) raising
## Upgrades.coin_magnet_mult (the augment/item hook) extends the reach so the
## far coin gets collected too.

const FAR_POS := Vector2(100, 220)   # 120 px below the player: outside base 48

var _frames := 0
var _near_ok := false
var _far_stays_ok := false
var _mult_ok := false
var _player: Player
var _far_coin: Coin


func _ready() -> void:
	GameState.reset_gold()
	Upgrades.coin_magnet_mult = 1.0

	_player = load("res://actors/player/player.tscn").instantiate()
	_player.position = Vector2(100, 100)
	add_child(_player)

	# Near coin: 40 px away — inside the base 48 px radius but well beyond
	# touch range, so only the magnet can explain it being collected.
	var near := _spawn_coin(_player.position + Vector2(40, 0))
	# Far coin: 120 px away — outside base radius, must NOT move.
	_far_coin = _spawn_coin(FAR_POS)
	near.name = "NearCoin"


## Scatter speeds zeroed so positions are deterministic.
func _spawn_coin(at: Vector2) -> Coin:
	var coin: Coin = load("res://items/coin/coin.tscn").instantiate()
	coin.scatter_speed_min = 0.0
	coin.scatter_speed_max = 0.0
	add_child(coin)
	coin.global_position = at
	return coin


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 60:
		# ~1s: the near coin has been pulled in and paid out; the far one sat still.
		_near_ok = GameState.gold == 5 and not has_node("NearCoin")
		_far_stays_ok = is_instance_valid(_far_coin) \
			and _far_coin.global_position.distance_to(FAR_POS) < 2.0
		# (3) Augment hook: triple the magnet radius -> 144 px covers the far coin.
		Upgrades.coin_magnet_mult = 3.0
	if _frames >= 150:
		_mult_ok = GameState.gold == 10 and not is_instance_valid(_far_coin)
		Upgrades.coin_magnet_mult = 1.0
		var all_ok := _near_ok and _far_stays_ok and _mult_ok
		print("COIN MAGNET TEST: %s (near=%s far_stays=%s mult=%s gold=%d)" % [
			"PASS" if all_ok else "FAIL", _near_ok, _far_stays_ok, _mult_ok,
			GameState.gold
		])
		get_tree().quit(0 if all_ok else 1)
