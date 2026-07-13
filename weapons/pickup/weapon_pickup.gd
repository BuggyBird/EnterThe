class_name WeaponPickup
extends Area2D
## A weapon lying on the ground. Walk into range to reveal its name, press the
## interact key to add it to your inventory. Data-driven: assign any WeaponData
## and the pickup tints/labels itself accordingly.

@export var weapon_data: WeaponData

@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label

var _player: Player = null
var _time := 0.0
var _base_y := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_base_y = sprite.position.y
	if weapon_data:
		sprite.modulate = weapon_data.color
		label.text = "[E] " + weapon_data.display_name
	label.visible = false


func _process(delta: float) -> void:
	# Gentle bob so pickups read as interactive.
	_time += delta
	sprite.position.y = _base_y + sin(_time * 3.0) * 3.0
	if _player and Input.is_action_just_pressed("interact"):
		_collect()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null
		label.visible = false


func _collect() -> void:
	_player.weapon_holder.add_weapon(weapon_data)
	queue_free()
