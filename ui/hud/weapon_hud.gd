extends CanvasLayer
## Minimal on-screen readout of the equipped weapon and its ammo. Purely a
## listener on EventBus — it never references the player or weapon directly, so
## it stays decoupled and will keep working as those systems evolve.

@onready var name_label: Label = $NameLabel
@onready var ammo_label: Label = $AmmoLabel


func _ready() -> void:
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	EventBus.weapon_ammo_changed.connect(_on_ammo_changed)


func _on_weapon_equipped(weapon_data: Resource) -> void:
	name_label.text = weapon_data.display_name if weapon_data else ""


func _on_ammo_changed(clip: int, reserve: int) -> void:
	var reserve_text := "∞" if reserve < 0 else str(reserve)
	ammo_label.text = "%d / %s" % [clip, reserve_text]
