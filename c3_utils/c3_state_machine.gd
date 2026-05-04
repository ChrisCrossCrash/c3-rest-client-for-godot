# C3 Godot Utils
# v2.1.0
# File revision: 2026-04-28

@tool
class_name C3StateMachine
extends Node
## Finite state machine node for coordinating [C3State] child nodes.
##
## C3StateMachine manages state transitions and dispatches engine callbacks
## (input, frame, and physics processing) to the currently active state.
##
## States are implemented as [C3State] nodes added as children of this node.
## Each child state receives a shared [member C3State.context] reference,
## typically pointing to the node being controlled by the state machine.
##
## State transitions are requested by returning a [C3State] from one of a
## state's processing methods. The state machine handles calling
## [method C3State.exit] on the outgoing state and [method C3State.enter]
## on the incoming state.
##
## This node is intended to be initialized explicitly via [method init]
## rather than relying on [_ready], allowing the caller to control when
## the state machine becomes active.
##
## Usage example:
## [codeblock]
## var sm := $StateMachine
## sm.init(self)
## [/codeblock]
##
## This script is safe to run in the editor and provides configuration
## warnings when misconfigured.


@export var starting_state: C3State

var current_state: C3State


## Initializes the state machine by giving each child state a reference to the
## context node it belongs to and enter the default starting_state.
func init(context: Node) -> void:
    for child: C3State in get_children():
        child.context = context

    # Initialize to the default state
    change_state(starting_state)


## Changes to the new state by first calling any exit logic on the current state.
func change_state(new_state: C3State) -> void:
    var previous_state := current_state
    if current_state:
        current_state.exit()

    current_state = new_state
    current_state.enter(previous_state)


func _physics_process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    var new_state = current_state.process_physics(delta)
    if new_state:
        change_state(new_state)


func _unhandled_input(event: InputEvent) -> void:
    var new_state = current_state.process_input(event)
    if new_state:
        change_state(new_state)


func _process(delta: float) -> void:
    if Engine.is_editor_hint():
        return
    var new_state = current_state.process_frame(delta)
    if new_state:
        change_state(new_state)


func _get_configuration_warnings() -> PackedStringArray:
    var warnings := PackedStringArray()

    if not starting_state:
        warnings.append("Starting state is not set. Assign a C3State to 'starting_state'.")

    if get_child_count() == 0:
        warnings.append(
            "This state machine has no child states. "
            + "Add one or more C3State nodes as children."
        )

    for child in get_children(true):
        if not child is C3State:
            warnings.append(
                "Child node '%s' is not a C3State instance." % child.name
            )

    return warnings


func _notification(what: int) -> void:
    if not Engine.is_editor_hint():
        return

    if what in [
        NOTIFICATION_CHILD_ORDER_CHANGED,
        NOTIFICATION_READY,
        NOTIFICATION_EDITOR_PRE_SAVE,
    ]:
        update_configuration_warnings()
