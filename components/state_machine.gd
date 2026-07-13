class_name StateMachine
extends Node
## A generic finite state machine.
##
## Add `State` nodes as children in the editor, then set `initial_state` to one
## of them. The machine forwards input / process / physics callbacks to the
## active state and performs transitions when a state emits `transitioned`.
##
## Reused across the whole project: the player, every enemy, and bosses all
## drive their behaviour through one of these. Distinct behaviour = different
## State child scripts, NOT a deep class hierarchy.

## The state entered when the machine starts.
@export var initial_state: State

var current_state: State

## Lower-cased node name -> State, for quick transition lookups.
var _states: Dictionary = {}


func _ready() -> void:
	# Register every child State and listen for its transition requests.
	# Also remember the first State so we can fall back to it if needed.
	var first_state: State = null
	for child in get_children():
		if child is State:
			if first_state == null:
				first_state = child
			_states[child.name.to_lower()] = child
			child.transitioned.connect(_on_state_transitioned)

	# `initial_state` can be set in the inspector, but exported node references
	# don't always resolve (e.g. in hand-authored scenes). Fall back to the
	# first State child so the machine always starts in a valid state.
	if initial_state == null:
		initial_state = first_state

	# Wait until the owning actor is fully ready so states can safely touch it.
	if owner and not owner.is_node_ready():
		await owner.ready

	if initial_state:
		current_state = initial_state
		current_state.enter()


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _on_state_transitioned(next_state_name: StringName) -> void:
	var next_state: State = _states.get(String(next_state_name).to_lower())
	if next_state == null:
		push_warning("StateMachine: no state named '%s'." % next_state_name)
		return
	if next_state == current_state:
		return
	if current_state:
		current_state.exit()
	current_state = next_state
	current_state.enter()
