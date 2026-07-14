extends Node
## Headless automated test for the monster AI. Run as a SCENE:
##   godot --headless --path <proj> res://tests/monster_test.tscn
##
## Spawns a Sewer Gunner far from the player and verifies the whole loop:
## (1) it chases toward its preferred fighting range, (2) it fires ENEMY
## projectiles (correct team: EnemyHitbox layer, no player-upgrade buffs),
## (3) those projectiles actually hurt the player.

var _frames := 0
var _player: Player
var _monster: Monster
var _start_dist := 0.0
var _start_health := 0.0
var _enemy_shot_seen := false
var _shot_layer_ok := false


func _ready() -> void:
	_player = load("res://actors/player/player.tscn").instantiate()
	_player.position = Vector2.ZERO
	add_child(_player)
	_start_health = _player.get_node("Health").current_health

	_monster = load("res://actors/enemies/monster.tscn").instantiate()
	_monster.data = load("res://resources/monsters/rat_gunner.tres")
	_monster.position = Vector2(420, 0)
	add_child(_monster)
	_start_dist = _monster.global_position.distance_to(_player.global_position)


func _physics_process(_delta: float) -> void:
	_frames += 1
	# Watch for enemy projectiles as they fly.
	for child in get_children():
		if child is Projectile and not child.friendly:
			_enemy_shot_seen = true
			_shot_layer_ok = child.collision_layer == 16 and child.collision_mask == 33
	if _frames >= 300:
		var dist := _monster.global_position.distance_to(_player.global_position)
		var approached := dist < _start_dist - 100.0
		var hurt: bool = _player.get_node("Health").current_health < _start_health
		var all_ok := approached and _enemy_shot_seen and _shot_layer_ok and hurt
		print("MONSTER TEST: %s (approached=%s [%.0f->%.0f] shot=%s layer=%s hurt=%s)" % [
			"PASS" if all_ok else "FAIL", approached, _start_dist, dist,
			_enemy_shot_seen, _shot_layer_ok, hurt
		])
		get_tree().quit(0 if all_ok else 1)
