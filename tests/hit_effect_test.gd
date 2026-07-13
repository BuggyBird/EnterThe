extends Node
## Verifies a bullet hitting an ENEMY spawns a (tinted) HitEffect burst, and that
## hitting a WALL does not.
##   godot --headless --path <proj> res://tests/hit_effect_test.tscn

func _ready() -> void:
	var ok := true
	Upgrades.reset()
	var data: ProjectileData = load("res://projectiles/data/basic_bolt.tres")

	# --- Enemy hit: a hurtbox + health the projectile deals damage to. ---
	var health := HealthComponent.new()
	add_child(health)
	var hurtbox := HurtboxComponent.new()
	hurtbox.health_component = health
	add_child(hurtbox)

	var proj: Projectile = load("res://projectiles/projectile.tscn").instantiate()
	proj.setup(data, Vector2.RIGHT, Vector2(50, 60))
	add_child(proj)
	proj._on_area_entered(hurtbox)   # simulate the overlap

	var effects := _count_effects()
	if effects.size() != 1:
		ok = false
		print("  expected 1 HitEffect after enemy hit, got %d" % effects.size())
	elif effects[0].modulate != data.color:
		ok = false
		print("  effect not tinted to bullet color")
	elif not effects[0].global_position.is_equal_approx(Vector2(50, 60)):
		ok = false
		print("  effect spawned at wrong spot: %s" % effects[0].global_position)

	# --- Wall hit: should NOT spawn an effect. ---
	var proj2: Projectile = load("res://projectiles/projectile.tscn").instantiate()
	proj2.setup(data, Vector2.RIGHT, Vector2(200, 0))
	add_child(proj2)
	proj2._on_body_entered(StaticBody2D.new())
	if _count_effects().size() != 1:
		ok = false
		print("  wall hit spawned an effect (should not)")

	print("HIT EFFECT TEST: %s (%d burst)" % ["PASS" if ok else "FAIL", _count_effects().size()])
	get_tree().quit(0 if ok else 1)


func _count_effects() -> Array:
	var found: Array = []
	for child in get_tree().current_scene.get_children():
		if child is HitEffect:
			found.append(child)
	return found
