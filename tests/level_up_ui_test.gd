extends Node
## Verifies the level-up popup flow: leveling up pauses the game and shows 3
## cards; picking one applies the upgrade, closes the popup, and unpauses.
##   godot --headless --path <proj> res://tests/level_up_ui_test.tscn

var _ui: CanvasLayer
var _frames := 0
var _checked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep ticking while the popup pauses
	RNG.set_seed(11)
	Upgrades.reset()
	_ui = load("res://ui/level_up/level_up_ui.tscn").instantiate()
	add_child(_ui)
	EventBus.player_leveled_up.emit(2)


func _process(_delta: float) -> void:
	if _checked:
		return
	_frames += 1
	if _frames < 3:
		return
	_checked = true

	var ok := true
	if not (_ui._root.visible and get_tree().paused):
		ok = false
		print("  popup not visible/paused after level up")

	var cards: Array = []
	for child in _ui._cards_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			cards.append(child)
	if cards.size() != 3:
		ok = false
		print("  expected 3 cards, got %d" % cards.size())

	if ok:
		cards[0].pressed.emit()
		var applied := false
		for def in Upgrades.POOL:
			if Upgrades.stacks_of(def["id"]) > 0:
				applied = true
		if not applied:
			ok = false
			print("  picking a card applied nothing")
		if _ui._root.visible or get_tree().paused:
			ok = false
			print("  popup did not close/unpause after pick")

	print("LEVEL UP UI TEST: %s" % ["PASS" if ok else "FAIL"])
	get_tree().paused = false
	Upgrades.reset()
	get_tree().quit(0 if ok else 1)
