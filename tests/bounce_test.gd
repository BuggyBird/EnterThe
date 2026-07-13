extends Node
## Verifies the Poltergeist Ricochet upgrade: with a bounce banked, a projectile
## fired into a wall reflects (survives, direction reversed) instead of despawning;
## without bounces it still dies on walls.
##   godot --headless --path <proj> res://tests/bounce_test.tscn

var _frames := 0
var _bouncy: Projectile
var _plain: Projectile


func _ready() -> void:
	Upgrades.reset()

	# A wall 120px to the right (World layer 1).
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(140, 0)
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 600)
	cs.shape = rect
	wall.add_child(cs)
	add_child(wall)

	var data: ProjectileData = load("res://projectiles/data/basic_bolt.tres")

	Upgrades.apply(&"bounce")
	_bouncy = load("res://projectiles/projectile.tscn").instantiate()
	_bouncy.setup(data, Vector2.RIGHT, Vector2.ZERO)
	add_child(_bouncy)

	Upgrades.reset()  # plain projectile spawns with no bounces
	_plain = load("res://projectiles/projectile.tscn").instantiate()
	_plain.setup(data, Vector2.RIGHT, Vector2(0, 100))
	add_child(_plain)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 25:
		return

	var bounced: bool = is_instance_valid(_bouncy) and not _bouncy.is_queued_for_deletion() \
		and _bouncy.direction.x < 0.0
	var plain_died: bool = not is_instance_valid(_plain) or _plain.is_queued_for_deletion()

	var ok := bounced and plain_died
	if not ok:
		var detail := "bouncy_alive=%s dir=%s plain_died=%s" % [
			is_instance_valid(_bouncy),
			_bouncy.direction if is_instance_valid(_bouncy) else "n/a", plain_died]
		print("  " + detail)
	print("BOUNCE TEST: %s" % ["PASS" if ok else "FAIL"])
	Upgrades.reset()
	get_tree().quit(0 if ok else 1)
