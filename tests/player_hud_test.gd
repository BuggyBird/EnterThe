extends Node
## Headless test: the HUD's player health bar tracks the player's health.
##   godot --headless --path <proj> res://tests/player_hud_test.tscn

var _frames := 0
var _hud: CanvasLayer
var _player: Player


func _ready() -> void:
	_hud = load("res://ui/hud/weapon_hud.tscn").instantiate()
	add_child(_hud)   # HUD first, like the real scenes, so it hears the spawn
	_player = load("res://actors/player/player.tscn").instantiate()
	add_child(_player)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames == 2:
		_player.get_node("Health").take_damage(DamageInfo.new(2.0, self, Vector2.ZERO))
	if _frames >= 5:
		var bar: ProgressBar = _hud.get_node("PlayerHealthBar")
		var text: String = _hud.get_node("PlayerHealthBar/HealthText").text
		var max_hp: float = _player.get_node("Health").max_health
		var ok := bar.max_value == max_hp and bar.value == max_hp - 2.0 \
			and text == "%d / %d" % [roundi(max_hp - 2.0), roundi(max_hp)]
		print("PLAYER HUD TEST: %s (bar=%.0f/%.0f text='%s')" % [
			"PASS" if ok else "FAIL", bar.value, bar.max_value, text])
		get_tree().quit(0 if ok else 1)
