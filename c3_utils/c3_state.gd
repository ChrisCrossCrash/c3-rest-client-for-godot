# C3 Godot Utils
# v2.0.0
# File revision: 2026-04-28

class_name C3State
extends Node
## Base class for a single state in a C3StateMachine.
##
## A state encapsulates behavior for a specific mode of operation and may
## request a transition to another state by returning a C3State from one
## of its process methods.
##
## Subclasses should override one or more lifecycle or processing methods
## to implement custom behavior.


## Assigned by the parent C3StateMachine and typically
## refers to the node being controlled by the state machine.
var context: Node


## Called when the state becomes active.
## [param from] is the state that was active immediately before this one,
## or [code]null[/code] when the state machine first initializes.[br]
##
## Override this method to perform setup logic such as resetting timers,
## enabling input, or initializing state-specific data.
func enter(_from: C3State) -> void:
    pass


## Called just before the state is exited.
##
## Override this method to perform cleanup logic such as stopping effects,
## disconnecting signals, or saving transient state.
func exit() -> void:
    pass


## Handles input events while this state is active.
##
## Return a [C3State] to request an immediate transition to that state.
## Return [code]null[/code] to remain in the current state.
func process_input(_event: InputEvent) -> C3State:
    return null


## Called once per rendered frame while this state is active.
##
## Return a [C3State] to request a transition to that state.
## Return [code]null[/code] to remain in the current state.
func process_frame(_delta: float) -> C3State:
    return null


## Called once per physics tick while this state is active.
##
## Return a [C3State] to request a transition to that state.
## Return [code]null[/code] to remain in the current state.
func process_physics(_delta: float) -> C3State:
    return null
