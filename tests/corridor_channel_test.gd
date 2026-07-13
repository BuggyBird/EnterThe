extends Node2D
## Regression: every corridor's walkable channel must be completely free of World
## collision, mouth to mouth and continuing through both door openings into the
## rooms. Point-queries a dense grid over each channel across several seeds and
## fails on ANY solid hit — catching wall/trim tiles left across a corridor, door
## carves that don't line up with the corridor, or stray wall stubs.
##   godot --headless --path <proj> res://tests/corridor_channel_test.tscn

const INSET := 5.0          ## Stay this far off the channel's side walls.
const STEP := 8.0           ## Sample spacing along and across.
const INTO_ROOM := 48.0     ## Keep scanning this far past each mouth, into the rooms.

var _seeds := [1, 7, 13, 21, 42]
var _si := 0
var _dungeon: Node2D
var _frames := 0
var _blocked := 0
var _channels := 0
var _reports: Array[String] = []


func _ready() -> void:
	_load_seed()


func _load_seed() -> void:
	if _dungeon:
		_dungeon.queue_free()
	RNG.set_seed(_seeds[_si])
	_dungeon = load("res://procgen/dungeon.tscn").instantiate()
	add_child(_dungeon)
	_frames = 0


func _physics_process(_d: float) -> void:
	_frames += 1
	if _frames < 4:
		return

	var space := get_world_2d().direct_space_state
	for entry in _dungeon._map_corridors:
		_channels += 1
		var pts: PackedVector2Array = entry.get("points",
			PackedVector2Array([entry["a"], entry["b"]]))
		for i in pts.size() - 1:
			_scan_channel(space, pts[i], pts[i + 1], i == 0, i == pts.size() - 2)

	_si += 1
	if _si < _seeds.size():
		_load_seed()
		return

	for r in _reports:
		print("  " + r)
	var ok := _blocked == 0 and _channels >= 10
	print("CORRIDOR CHANNEL TEST: %s (channels=%d blocked_points=%d)" % [
		"PASS" if ok else "FAIL", _channels, _blocked])
	get_tree().quit(0 if ok else 1)


## Sample a grid across one 48px channel segment. Mouth ends keep scanning
## INTO_ROOM past the mouth (through the door opening); elbow ends scan on into
## the corner square shared with the next segment, so turns are covered too. Any
## World-layer hit is a blocker the player could get stuck on.
func _scan_channel(space: PhysicsDirectSpaceState2D, a: Vector2, b: Vector2,
		mouth_start: bool, mouth_end: bool) -> void:
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var length := a.distance_to(b)
	var half := DungeonGenerator.DOOR_WIDTH * 0.5 - INSET
	var start_ext := INTO_ROOM if mouth_start else half
	var end_ext := INTO_ROOM if mouth_end else half
	var hits_here := 0
	var first_hit := Vector2.ZERO
	var t := -start_ext
	while t <= length + end_ext:
		var s := -half
		while s <= half:
			var q := PhysicsPointQueryParameters2D.new()
			q.position = a + dir * t + side * s
			q.collision_mask = 1  # World
			if not space.intersect_point(q).is_empty():
				if hits_here == 0:
					first_hit = q.position
				hits_here += 1
			s += STEP
		t += STEP
	if hits_here > 0:
		_blocked += hits_here
		_reports.append("seed %d corridor %s->%s: %d blocked points, first at %s" % [
			_seeds[_si], a, b, hits_here, first_hit])
