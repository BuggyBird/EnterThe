extends Node
## Run-local XP + upgrade state (autoload singleton "Upgrades").
##
## Enemies killed award XP; crossing the level threshold emits
## EventBus.player_leveled_up, which the LevelUpUI answers with a 3-card choice.
## Chosen upgrades bump the modifier fields below, which combat code reads live:
##   - Projectile: damage_mult, bullet_size_mult, bullet_speed_mult, bounces, pierce_bonus
##   - Weapon:     fire_rate_mult
##   - Player:     move_speed_mult (and vitality applied on spawn)
## Wiped by reset() when a new run starts (RunManager, later milestone).

const XP_PER_KILL := 25

## Rarity tiers, rarest last. Each maps to one of the frame images in Assets/Perks
## (base 1..5) and to a colour used across the level-up and inventory UIs. Rarer
## perks roll less often (RARITY_WEIGHTS).
enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }
const RARITY_NAMES: Array[String] = ["Common", "Rare", "Epic", "Legendary", "Mythic"]
const RARITY_COLORS: Array[Color] = [
	Color(0.74, 0.77, 0.82),   # Common  — silver
	Color(0.4, 0.66, 0.98),    # Rare    — blue
	Color(0.72, 0.42, 0.98),   # Epic    — violet
	Color(0.98, 0.72, 0.28),   # Legendary — gold
	Color(0.98, 0.34, 0.42),   # Mythic  — crimson
]
## Relative roll weights per rarity (rarer = scarcer).
const RARITY_WEIGHTS: Array[float] = [100.0, 55.0, 26.0, 11.0, 4.0]

## The card pool. `max_stacks` caps how often one upgrade can be taken; maxed
## upgrades stop appearing. `rarity` picks its frame + colour and roll odds.
## Adding an upgrade = add an entry + a branch in apply().
const POOL := [
	{"id": &"power", "name": "Soul Power", "desc": "+25% damage", "max_stacks": 5, "rarity": Rarity.COMMON},
	{"id": &"swift", "name": "Wraith Stride", "desc": "+15% move speed", "max_stacks": 5, "rarity": Rarity.COMMON},
	{"id": &"vitality", "name": "Ectoplasm Heart", "desc": "+2 max health, heal 2", "max_stacks": 5, "rarity": Rarity.RARE},
	{"id": &"rapid", "name": "Restless Trigger", "desc": "+20% fire rate", "max_stacks": 5, "rarity": Rarity.RARE},
	{"id": &"velocity", "name": "Howling Shots", "desc": "+25% bullet speed", "max_stacks": 5, "rarity": Rarity.EPIC},
	{"id": &"big_bullets", "name": "Grave Caliber", "desc": "+30% bullet size", "max_stacks": 5, "rarity": Rarity.EPIC},
	{"id": &"bounce", "name": "Poltergeist Ricochet", "desc": "Bullets bounce off walls (+1)", "max_stacks": 3, "rarity": Rarity.LEGENDARY},
	{"id": &"pierce", "name": "Spectral Pierce", "desc": "Bullets pierce +1 enemy", "max_stacks": 3, "rarity": Rarity.MYTHIC},
]


## Path to the frame image for a rarity (Common -> base 1 ... Mythic -> base 5).
static func rarity_frame_path(rarity: int) -> String:
	return "res://Assets/Perks/base %d.png" % (rarity + 1)

# --- XP / level ----------------------------------------------------------------
var xp := 0
var level := 1

# --- Live modifiers (read by combat code every shot/frame) ----------------------
var damage_mult := 1.0
var bullet_size_mult := 1.0
var bullet_speed_mult := 1.0
var fire_rate_mult := 1.0
var move_speed_mult := 1.0
var bounces := 0
var pierce_bonus := 0

var _stacks: Dictionary = {}   ## id -> times taken
var _player: Node


func _ready() -> void:
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.player_spawned.connect(_on_player_spawned)


## Wipe everything for a fresh run.
func reset() -> void:
	xp = 0
	level = 1
	damage_mult = 1.0
	bullet_size_mult = 1.0
	bullet_speed_mult = 1.0
	fire_rate_mult = 1.0
	move_speed_mult = 1.0
	bounces = 0
	pierce_bonus = 0
	_stacks.clear()


func xp_to_next() -> int:
	return 75 + 25 * level   # level 1 -> 100, 2 -> 125, ...


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		EventBus.player_leveled_up.emit(level)
	EventBus.player_xp_changed.emit(xp, xp_to_next(), level)


## Pick up to `count` distinct, non-maxed upgrades for the level-up cards, weighted
## by rarity so rarer perks surface less often.
func roll_choices(count: int) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for def in POOL:
		if stacks_of(def["id"]) < int(def["max_stacks"]):
			available.append(def)
	var choices: Array[Dictionary] = []
	while choices.size() < count and not available.is_empty():
		var i := _weighted_index(available)
		choices.append(available[i])
		available.remove_at(i)
	return choices


## Index into `defs` chosen with probability proportional to each entry's rarity
## weight (via the seeded RNG so runs stay reproducible).
func _weighted_index(defs: Array[Dictionary]) -> int:
	var total := 0.0
	for def in defs:
		total += RARITY_WEIGHTS[int(def["rarity"])]
	var roll := RNG.randf() * total
	for i in defs.size():
		roll -= RARITY_WEIGHTS[int(defs[i]["rarity"])]
		if roll <= 0.0:
			return i
	return defs.size() - 1


func stacks_of(id: StringName) -> int:
	return int(_stacks.get(id, 0))


## Every upgrade the player currently owns (stacks > 0), for the inventory screen.
## Each entry: {"name": String, "desc": String, "stacks": int}.
func owned_upgrades() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def in POOL:
		var owned := stacks_of(def["id"])
		if owned > 0:
			out.append({"name": def["name"], "desc": def["desc"], "stacks": owned,
				"rarity": int(def["rarity"])})
	return out


## Apply a chosen upgrade by id.
func apply(id: StringName) -> void:
	match id:
		&"power": damage_mult += 0.25
		&"big_bullets": bullet_size_mult += 0.30
		&"swift": move_speed_mult += 0.15
		&"rapid": fire_rate_mult += 0.20
		&"velocity": bullet_speed_mult += 0.25
		&"bounce": bounces += 1
		&"pierce": pierce_bonus += 1
		&"vitality": _apply_vitality()
		_:
			push_warning("Unknown upgrade id: %s" % id)
			return
	_stacks[id] = stacks_of(id) + 1
	EventBus.upgrade_chosen.emit(id)


func _apply_vitality() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var hc: HealthComponent = _player.get_node_or_null("Health")
	if hc:
		hc.max_health += 2.0
		hc.heal(2.0)


func _on_entity_died(entity: Node) -> void:
	if entity is Player:
		return
	add_xp(XP_PER_KILL)


## Keep a player ref for vitality; re-apply banked vitality to a fresh player
## (e.g. after a floor regen respawns them with base max health).
func _on_player_spawned(player: Node) -> void:
	_player = player
	var banked := stacks_of(&"vitality")
	if banked > 0:
		var hc: HealthComponent = player.get_node_or_null("Health")
		if hc:
			hc.max_health += 2.0 * banked
			hc.heal(2.0 * banked)
