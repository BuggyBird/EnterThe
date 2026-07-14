extends CanvasLayer
## Minimal on-screen readout of the equipped weapon and its ammo. Purely a
## listener on EventBus — it never references the player or weapon directly, so
## it stays decoupled and will keep working as those systems evolve.

@onready var name_label: Label = $NameLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var gold_label: Label = $GoldLabel
@onready var health_bar: ProgressBar = $PlayerHealthBar
@onready var health_text: Label = $PlayerHealthBar/HealthText


func _ready() -> void:
	EventBus.weapon_equipped.connect(_on_weapon_equipped)
	EventBus.weapon_ammo_changed.connect(_on_ammo_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	_on_gold_changed(GameState.gold)
	_style_health_bar()


func _on_gold_changed(total: int) -> void:
	gold_label.text = "%d g" % total


func _on_player_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_text.text = "%d / %d" % [roundi(current), roundi(maximum)]


## Dark slab + blood-red fill, built in code so no extra theme asset is needed.
func _style_health_bar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.06, 0.11, 0.9)
	bg.border_color = Color(0.35, 0.28, 0.42)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.19, 0.25)
	fill.set_corner_radius_all(3)
	health_bar.add_theme_stylebox_override("background", bg)
	health_bar.add_theme_stylebox_override("fill", fill)
	health_text.add_theme_font_size_override("font_size", 10)


func _on_weapon_equipped(weapon_data: Resource) -> void:
	name_label.text = weapon_data.display_name if weapon_data else ""


func _on_ammo_changed(clip: int, reserve: int) -> void:
	var reserve_text := "∞" if reserve < 0 else str(reserve)
	ammo_label.text = "%d / %s" % [clip, reserve_text]
