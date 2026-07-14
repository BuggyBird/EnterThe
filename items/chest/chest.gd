class_name Chest
extends Area2D
## A locked treasure chest. Walk up to see its rarity and price; press interact
## to PAY gold to open it (gold drops from slain enemies). Opening plays the
## lid animation for its rarity, then the loot pops out as a weapon pickup.
## Rarity reuses the perk system's tiers/colors so it reads consistently.

const PICKUP_SCENE_PATH := "res://weapons/pickup/weapon_pickup.tscn"
## Gold price per rarity (Common..Mythic).
const COSTS: Array[int] = [20, 40, 70, 110, 160]
## Fallback loot pool when nothing is assigned (mirrors the treasure rooms).
const FALLBACK_LOOT: Array[String] = [
	"res://weapons/data/bone_railbolt.tres",
	"res://weapons/data/bonerang.tres",
	"res://weapons/data/whisperwind_longbow.tres",
	"res://weapons/data/soulwood_repeater.tres",
]

@export_enum("Common", "Rare", "Epic", "Legendary", "Mythic") var rarity: int = 0
## What's inside. Left empty = a random weapon from FALLBACK_LOOT.
@export var loot: WeaponData

@onready var anim: AnimatedSprite2D = $Anim
@onready var label: Label = $Label

var _player: Player = null
var _opened := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	anim.play(_anim_name("closed"))
	label.text = "[E] %s Chest — %d g" % [Upgrades.RARITY_NAMES[rarity], cost()]
	label.modulate = Upgrades.RARITY_COLORS[rarity]
	label.visible = false


func cost() -> int:
	return COSTS[rarity]


func _process(_delta: float) -> void:
	if _player and not _opened and Input.is_action_just_pressed("interact"):
		try_open()


## Pay and open. Returns false (with a red price flash) when gold is short.
func try_open() -> bool:
	if _opened:
		return false
	if not GameState.try_spend_gold(cost()):
		_flash_denied()
		return false
	_opened = true
	label.visible = false
	anim.play(_anim_name("open"))
	anim.animation_finished.connect(_spawn_loot, CONNECT_ONE_SHOT)
	EventBus.chest_opened.emit(rarity)
	return true


func _spawn_loot() -> void:
	var data := loot
	if data == null:
		data = load(RNG.pick(FALLBACK_LOOT))
	var pickup: Node2D = load(PICKUP_SCENE_PATH).instantiate()
	pickup.weapon_data = data
	get_parent().add_child(pickup)
	pickup.global_position = global_position + Vector2(0, 30)


## Too poor: the price tag flashes red and the chest rocks in place.
func _flash_denied() -> void:
	label.modulate = Color(1.0, 0.25, 0.3)
	var tween := create_tween()
	tween.tween_property(label, "modulate", Upgrades.RARITY_COLORS[rarity], 0.5)
	var rock := create_tween()
	rock.tween_property(anim, "position:x", 2.0, 0.05)
	rock.tween_property(anim, "position:x", -2.0, 0.05)
	rock.tween_property(anim, "position:x", 0.0, 0.05)


func _anim_name(suffix: String) -> StringName:
	return StringName(Upgrades.RARITY_NAMES[rarity].to_lower() + "_" + suffix)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		label.visible = not _opened


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		label.visible = false
