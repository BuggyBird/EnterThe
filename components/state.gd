class_name State
extends Node
## Base class for a single state in a StateMachine.
##
## Subclass this and override the hooks you need. To change state, emit
## `transitioned` with the TARGET state's node name (case-insensitive), e.g.
## `transitioned.emit(&"move")`. The owning StateMachine handles the switch.
##
## Each concrete state typically caches its actor with:
##     @onready var player: Player = owner
## because `owner` is the root of the scene the state lives in.

## Emitted to request a transition to another state by node name.
signal transitioned(next_state_name: StringName)


## Called once when this state becomes active.
func enter() -> void:
	pass


## Called once when leaving this state.
func exit() -> void:
	pass


## Forwarded from the machine's `_unhandled_input`.
func handle_input(_event: InputEvent) -> void:
	pass


## Forwarded from the machine's `_process` (rendering-rate logic).
func update(_delta: float) -> void:
	pass


## Forwarded from the machine's `_physics_process` (movement / physics).
func physics_update(_delta: float) -> void:
	pass
