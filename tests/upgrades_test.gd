extends Node
## Headless test for the Upgrades autoload: XP curve + level-up signal, kill XP,
## card rolling (distinct, non-maxed), and modifier application.
##   godot --headless --path <proj> res://tests/upgrades_test.tscn

var _level_ups: Array[int] = []


func _ready() -> void:
	var ok := true
	RNG.set_seed(7)
	Upgrades.reset()
	EventBus.player_leveled_up.connect(func(lv: int): _level_ups.append(lv))

	# XP curve: level 1 needs 100. 99 XP -> no level; +1 more -> level 2.
	Upgrades.add_xp(99)
	if Upgrades.level != 1 or not _level_ups.is_empty():
		ok = false
		print("  premature level-up at 99 xp")
	Upgrades.add_xp(1)
	if Upgrades.level != 2 or _level_ups != [2]:
		ok = false
		print("  expected level 2 after 100 xp, got level %d" % Upgrades.level)

	# One big XP dump can cross several thresholds at once.
	Upgrades.add_xp(1000)
	if Upgrades.level <= 2 or _level_ups.size() < 2:
		ok = false
		print("  big xp dump did not multi-level (level=%d)" % Upgrades.level)

	# Kills award XP (non-player entities only).
	var before := Upgrades.xp
	Upgrades._on_entity_died(Node2D.new())
	if Upgrades.xp != before + Upgrades.XP_PER_KILL:
		ok = false
		print("  kill did not award %d xp" % Upgrades.XP_PER_KILL)

	# Rolls: 3 distinct cards.
	var choices := Upgrades.roll_choices(3)
	var ids := {}
	for def in choices:
		ids[def["id"]] = true
	if choices.size() != 3 or ids.size() != 3:
		ok = false
		print("  roll not 3 distinct cards")

	# Applying upgrades moves the right modifiers.
	Upgrades.apply(&"power")
	Upgrades.apply(&"big_bullets")
	Upgrades.apply(&"bounce")
	if not (is_equal_approx(Upgrades.damage_mult, 1.25)
			and is_equal_approx(Upgrades.bullet_size_mult, 1.30)
			and Upgrades.bounces == 1):
		ok = false
		print("  modifiers wrong: dmg=%s size=%s bounce=%d" % [
			Upgrades.damage_mult, Upgrades.bullet_size_mult, Upgrades.bounces])

	# Maxed upgrades stop appearing in rolls.
	for i in 3:
		Upgrades.apply(&"pierce")
	for def in Upgrades.roll_choices(POOL_SIZE):
		if def["id"] == &"pierce":
			ok = false
			print("  maxed upgrade still offered")

	Upgrades.reset()
	if Upgrades.level != 1 or Upgrades.damage_mult != 1.0 or Upgrades.bounces != 0:
		ok = false
		print("  reset incomplete")

	print("UPGRADES TEST: %s" % ["PASS" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)


const POOL_SIZE := 8
