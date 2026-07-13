extends CanvasLayer
## Full-screen inventory + map overlay, toggled with Tab. Pauses the game and
## shows, on the left, every gun and perk the player owns, and on the right a
## minimap of the floor with the player's position and the rooms explored so far.
##
## Like the level-up screen it runs while the tree is paused (PROCESS_MODE_ALWAYS)
## and builds its UI in code — placeholder styling until the real art pass. It is
## a pure EventBus listener: it never reaches into the dungeon or player directly
## beyond the player reference handed to it by `player_spawned`.

## Chunkier display face for panel headings (body text uses the global theme font).
const DISPLAY_FONT := preload("res://Assets/Fonts/Jacquard24-Regular.ttf")

const PANEL_BG := Color(0.09, 0.08, 0.13, 0.96)
const HEADER_COLOR := Color(0.95, 0.85, 0.5)
const TEXT_COLOR := Color(0.9, 0.88, 0.96)
const MUTED_COLOR := Color(0.6, 0.58, 0.68)

var _root: Control
var _guns_box: VBoxContainer
var _perks_box: VBoxContainer
var _map_view: MapView
var _player: Node2D


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.map_generated.connect(_on_map_generated)
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.room_entered.connect(_on_room_entered)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if _root.visible:
		_close()
	else:
		_open()


func _open() -> void:
	_refresh_inventory()
	_root.visible = true
	_map_view.queue_redraw()
	get_tree().paused = true


func _close() -> void:
	_root.visible = false
	get_tree().paused = false


# --- Data ---------------------------------------------------------------------

func _on_player_spawned(player: Node) -> void:
	_player = player
	_map_view.set_player(player)


func _on_map_generated(rooms: Array, corridors: Array) -> void:
	_map_view.set_floor(rooms, corridors)


func _on_room_entered(room: Node) -> void:
	_map_view.discover(room)


## Rebuild the gun + perk lists from the live player/Upgrades state on open.
func _refresh_inventory() -> void:
	for child in _guns_box.get_children():
		child.queue_free()
	for child in _perks_box.get_children():
		child.queue_free()

	var weapons: Array[WeaponData] = []
	var equipped := -1
	if is_instance_valid(_player):
		var holder: WeaponHolder = _player.weapon_holder
		weapons = holder.get_owned_weapons()
		equipped = holder.get_equipped_index()
	if weapons.is_empty():
		_guns_box.add_child(_muted_label("(none)"))
	for i in weapons.size():
		_guns_box.add_child(_weapon_row(weapons[i], i == equipped))

	var perks := Upgrades.owned_upgrades()
	if perks.is_empty():
		_perks_box.add_child(_muted_label("(none)"))
	for perk in perks:
		_perks_box.add_child(_perk_row(perk))


# --- Widgets ------------------------------------------------------------------

## One gun row: a colour swatch (its identity tint) + name, with an arrow on the
## equipped weapon.
func _weapon_row(data: WeaponData, is_equipped: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var swatch := ColorRect.new()
	swatch.color = data.color
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(swatch)

	var label := Label.new()
	var prefix := "> " if is_equipped else ""
	label.text = "%s%s" % [prefix, data.display_name]
	label.add_theme_color_override("font_color",
		HEADER_COLOR if is_equipped else TEXT_COLOR)
	row.add_child(label)
	return row


func _perk_row(perk: Dictionary) -> Control:
	var label := Label.new()
	var stacks: int = perk["stacks"]
	var suffix := " x%d" % stacks if stacks > 1 else ""
	label.text = "%s%s — %s" % [perk["name"], suffix, perk["desc"]]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Tint the perk by its rarity so the inventory mirrors the level-up frames.
	var rarity: int = perk.get("rarity", 0)
	label.add_theme_color_override("font_color", Upgrades.RARITY_COLORS[rarity])
	label.add_theme_font_size_override("font_size", 12)
	return label


func _muted_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED_COLOR)
	return label


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", HEADER_COLOR)
	return label


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", MUTED_COLOR)
	label.add_theme_font_size_override("font_size", 13)
	return label


# --- Layout -------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_root.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	columns.add_child(_build_inventory_panel())
	columns.add_child(_build_map_panel())


func _build_inventory_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(244, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())

	var pad := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	pad.add_child(column)

	column.add_child(_header("INVENTORY"))
	column.add_child(_section_label("GUNS"))
	_guns_box = VBoxContainer.new()
	_guns_box.add_theme_constant_override("separation", 3)
	column.add_child(_guns_box)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)

	column.add_child(_section_label("PERKS"))
	_perks_box = VBoxContainer.new()
	_perks_box.add_theme_constant_override("separation", 3)
	column.add_child(_perks_box)
	return panel


func _build_map_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())

	var pad := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	pad.add_child(column)

	column.add_child(_header("MAP"))

	_map_view = MapView.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_map_view)

	var hint := Label.new()
	hint.text = "Tab / Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", MUTED_COLOR)
	hint.add_theme_font_size_override("font_size", 12)
	column.add_child(hint)
	return panel


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.35, 0.5, 0.8)
	return style
