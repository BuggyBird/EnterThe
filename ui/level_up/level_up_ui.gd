extends CanvasLayer
## Level-up card picker. Listens for EventBus.player_leveled_up, pauses the game,
## and offers 3 upgrade cards rolled from the Upgrades pool; clicking one applies
## it and resumes play. Multiple pending level-ups queue and show back to back.
##
## Each card is framed with the rarity artwork in Assets/Perks (base 1..5, one per
## Rarity tier) and coloured to match, so rarer perks read at a glance.
##
## Runs while the tree is paused (PROCESS_MODE_ALWAYS), like a menu. UI is built
## in code — placeholder styling until the real UI art pass.

const CARD_SIZE := Vector2(140, 210)       ## 2:3, matching the 64x96 frame art.
const CONTENT_INSET := Vector2(18, 24)      ## Keep text inside the ornate border.
const HOVER_SCALE := Vector2(1.09, 1.09)   ## Card pops out a touch on hover.
const HOVER_TINT := Color(1.15, 1.15, 1.15) ## And brightens (modulate >1 = brighten).
const HOVER_TIME := 0.09
## Chunkier display face for big headings (body text uses the global theme font).
const DISPLAY_FONT := preload("res://Assets/Fonts/Jacquard24-Regular.ttf")

var _root: Control
var _cards_box: HBoxContainer
var _title: Label
var _pending := 0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.player_leveled_up.connect(_on_leveled_up)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	_title = Label.new()
	_title.text = "LEVEL UP"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	_title.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06))
	_title.add_theme_constant_override("outline_size", 4)
	column.add_child(_title)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 16)
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_cards_box)


func _on_leveled_up(new_level: int) -> void:
	_pending += 1
	if not _root.visible:
		_title.text = "LEVEL %d" % new_level
		_show_choices()


func _show_choices() -> void:
	var choices := Upgrades.roll_choices(3)
	if choices.is_empty():
		# Everything maxed out — nothing to offer, skip the stop.
		_pending = 0
		_close()
		return

	get_tree().paused = true
	_root.visible = true
	for child in _cards_box.get_children():
		child.queue_free()

	for def in choices:
		_cards_box.add_child(_make_card(def))


## One framed perk card: rarity frame image over a tinted fill, with the rarity
## label, name, description, and owned-count. The whole card is a flat Button so a
## click anywhere selects it (children ignore the mouse so the press reaches it).
func _make_card(def: Dictionary) -> Control:
	var rarity := int(def["rarity"])
	var color: Color = Upgrades.RARITY_COLORS[rarity]

	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.add_theme_stylebox_override("normal", _empty_style())
	card.add_theme_stylebox_override("hover", _glow_style(color))
	card.add_theme_stylebox_override("pressed", _glow_style(color))
	card.pressed.connect(_on_card_picked.bind(StringName(def["id"])))
	card.mouse_entered.connect(_on_card_hover.bind(card, true))
	card.mouse_exited.connect(_on_card_hover.bind(card, false))

	# Dark, rarity-tinted fill behind the frame's transparent centre.
	var fill := ColorRect.new()
	fill.color = Color(color.r * 0.16, color.g * 0.16, color.b * 0.2, 0.94)
	_fill_rect(fill, 6.0)
	card.add_child(fill)

	# The ornate rarity frame, scaled up crisp (nearest) to the card size.
	var frame := TextureRect.new()
	frame.texture = load(Upgrades.rarity_frame_path(rarity))
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill_rect(frame, 0.0)
	card.add_child(frame)

	card.add_child(_build_content(def, rarity, color))
	return card


func _build_content(def: Dictionary, rarity: int, color: Color) -> Control:
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = CONTENT_INSET.x
	content.offset_top = CONTENT_INSET.y
	content.offset_right = -CONTENT_INSET.x
	content.offset_bottom = -CONTENT_INSET.y

	content.add_child(_card_label(Upgrades.RARITY_NAMES[rarity].to_upper(), 11, color))
	content.add_child(_card_label(def["name"], 15, Color(0.98, 0.96, 1.0), true))
	content.add_child(_card_label(def["desc"], 12, Color(0.85, 0.83, 0.9), true))

	var stacks: int = Upgrades.stacks_of(def["id"])
	if stacks > 0:
		content.add_child(_card_label("owned x%d" % stacks, 10, Color(0.65, 0.63, 0.72)))
	return content


## Card text must be READABLE above all: it uses the global theme font (Pixelify
## Sans — pixel-styled but legible), with a dark outline lifting it off the frame
## art. The blackletter face is reserved for big display headings.
func _card_label(text: String, font_size: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Anchor a child to fill its parent, optionally inset by `margin` on all sides,
## and let clicks pass through to the card button.
func _fill_rect(node: Control, margin: float) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = margin
	node.offset_top = margin
	node.offset_right = -margin
	node.offset_bottom = -margin
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Grow and brighten a card while the cursor is over it (and lift it above its
## neighbours). Tween is set to run even though the game tree is paused.
func _on_card_hover(card: Control, hovered: bool) -> void:
	card.pivot_offset = card.size * 0.5   # Scale about the card's centre.
	card.z_index = 1 if hovered else 0
	var tween := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", HOVER_SCALE if hovered else Vector2.ONE, HOVER_TIME)
	tween.parallel().tween_property(card, "modulate",
		HOVER_TINT if hovered else Color.WHITE, HOVER_TIME)


func _on_card_picked(id: StringName) -> void:
	Upgrades.apply(id)
	_pending -= 1
	if _pending > 0:
		_title.text = "LEVEL %d" % Upgrades.level
		_show_choices()
	else:
		_close()


func _close() -> void:
	_root.visible = false
	get_tree().paused = false


func _empty_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## A soft rarity-coloured glow drawn behind the card on hover/press.
func _glow_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.12)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2)
	style.border_color = Color(color.r, color.g, color.b, 0.9)
	style.set_expand_margin_all(3)
	return style
