extends Node
## Headless automated test for the combat pipeline. Run as a SCENE (not -s) so
## autoloads like EventBus are available:
##   godot --headless --path <proj> res://tests/combat_test.tscn --quit-after 40
##
## Spawns a dummy and a projectile overlapping it, lets physics run a few frames,
## then asserts the dummy took damage. Verifies projectile -> hurtbox -> health
## end to end without needing keyboard input.

var _frames := 0
var _health: HealthComponent
var _start_health := -1.0


func _ready() -> void:
	var dummy: Node2D = load("res://actors/enemies/dummy/dummy.tscn").instantiate()
	add_child(dummy)
	_health = dummy.get_node("Health")
	# HealthComponent._ready already ran (add_child is synchronous), so this is
	# the full starting health before any projectile touches it.
	_start_health = _health.current_health

	var projectile: Node = load("res://projectiles/projectile.tscn").instantiate()
	var data: ProjectileData = load("res://projectiles/data/basic_bolt.tres")
	# Spawn on top of the dummy so their areas overlap immediately.
	projectile.setup(data, Vector2.RIGHT, dummy.global_position)
	add_child(projectile)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames >= 20:
		var expected := _start_health - 10.0  # basic_bolt deals 10, pierce 0 = one hit
		var took_damage := is_equal_approx(_health.current_health, expected)
		print("COMBAT TEST: %s (health %.0f -> %.0f, expected %.0f)" % [
			"PASS" if took_damage else "FAIL",
			_start_health, _health.current_health, expected
		])
		get_tree().quit(0 if took_damage else 1)
