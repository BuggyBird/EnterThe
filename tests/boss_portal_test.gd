extends Node
## Headless automated test for the boss kill payout. Run as a SCENE:
##   godot --headless --path <proj> res://tests/boss_portal_test.tscn
##
## Verifies: (1) killing the boss spawns a weapon pickup AND a purple stage
## portal at the corpse, (2) walking into the portal emits
## EventBus.stage_portal_entered (the Dungeon's cue to advance + regenerate),
## (3) on the campaign's FINAL stage the boss still drops the weapon but no
## portal appears.

const FINAL_STAGE := preload("res://resources/stages/underhalls_3.tres")

var _frames := 0
var _room: RoomDef
var _player: Player
var _boss_killed := false
var _rewards_ok := false
var _portal_pos := Vector2.ZERO
var _portal_entered := false
var _entered_at_frame := -1


func _ready() -> void:
	Stages.start_run()   # stage 1: not final, so the portal must spawn
	EventBus.stage_portal_entered.connect(func() -> void: _portal_entered = true)

	# Standalone boss arena: RoomDef configures itself as BOSS from `category`.
	_room = load("res://rooms/boss/boss_arena.tscn").instantiate()
	add_child(_room)
	_player = load("res://actors/player/player.tscn").instantiate()
	_player.position = Vector2(-220, 140)   # inside the interior detector
	add_child(_player)


func _physics_process(_delta: float) -> void:
	_frames += 1
	# Entering the room begins the encounter (deferred): one big boss monster.
	if not _boss_killed:
		var boss := _find_boss()
		if boss != null:
			boss.get_node("Health").take_damage(DamageInfo.new(999.0, self, Vector2.ZERO))
			_boss_killed = true
		return
	# (1) Rewards appear (deferred spawn) at the corpse.
	if not _rewards_ok:
		var portal := _find_child_of(_room, StagePortal) as StagePortal
		var pickup := _find_child_of(_room, WeaponPickup) as WeaponPickup
		if portal != null:
			_rewards_ok = pickup != null and pickup.weapon_data != null \
				and portal.position.distance_to(pickup.position) < 80.0
			_portal_pos = portal.global_position
			# (2) Step into the portal.
			_player.global_position = _portal_pos
		return
	if _portal_entered and _entered_at_frame < 0:
		_entered_at_frame = _frames
		# (3) Final stage: weapon yes, portal no. Call the payout directly with
		# the endboss stage current; no NEW portal may appear.
		Stages.current = FINAL_STAGE
		_room._spawn_boss_rewards(Vector2(140, 140))
	if (_entered_at_frame > 0 and _frames >= _entered_at_frame + 5) or _frames >= 300:
		var portals := _count_children_of(_room, StagePortal)
		var pickups := _count_children_of(_room, WeaponPickup)
		var final_ok := portals == 1 and pickups == 2
		var all_ok := _rewards_ok and _portal_entered and final_ok
		print("BOSS PORTAL TEST: %s (rewards=%s entered=%s final=%s portals=%d pickups=%d)" % [
			"PASS" if all_ok else "FAIL", _rewards_ok, _portal_entered, final_ok,
			portals, pickups
		])
		get_tree().quit(0 if all_ok else 1)


func _find_boss() -> Node:
	for child in _room.get_children():
		if child is Monster:
			return child
	return null


func _find_child_of(parent: Node, klass) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, klass):
			return child
	return null


func _count_children_of(parent: Node, klass) -> int:
	var count := 0
	for child in parent.get_children():
		if is_instance_of(child, klass):
			count += 1
	return count
