extends GutTest

# --- Helpers ------------------------------------------------------------

## Returns true if any warning string contains the given substring.
func _warnings_contain(warnings: PackedStringArray, needle: String) -> bool:
    for w in warnings:
        if w.contains(needle):
            return true
    return false

# --- Tests --------------------------------------------------------------

## Minimal spy state that records calls and can request a transition.
class SpyState:
    extends C3State

    var entered := 0
    var exited := 0
    var frame_calls := 0
    var physics_calls := 0
    var input_calls := 0
    var last_from: C3State = null

    var return_on_frame: C3State = null
    var return_on_physics: C3State = null
    var return_on_input: C3State = null

    func enter(from: C3State) -> void:
        entered += 1
        last_from = from

    func exit() -> void:
        exited += 1

    func process_frame(_delta: float) -> C3State:
        frame_calls += 1
        return return_on_frame

    func process_physics(_delta: float) -> C3State:
        physics_calls += 1
        return return_on_physics

    func process_input(_event: InputEvent) -> C3State:
        input_calls += 1
        return return_on_input


func test_init_sets_context_for_all_children_and_enters_starting_state() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var ctx := Node.new()
    add_child_autofree(ctx)

    var a := SpyState.new()
    var b := SpyState.new()
    sm.add_child(a)
    sm.add_child(b)

    sm.starting_state = a
    sm.init(ctx)

    assert_eq(a.context, ctx, "State A context should be wired")
    assert_eq(b.context, ctx, "State B context should be wired")

    assert_eq(sm.current_state, a, "Should set current_state to starting_state")
    assert_eq(a.entered, 1, "Should enter starting_state exactly once")
    assert_eq(a.exited, 0, "Should not exit starting_state during init")


func test_change_state_exits_old_then_enters_new() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var a := SpyState.new()
    var b := SpyState.new()
    sm.add_child(a)
    sm.add_child(b)

    sm.change_state(a)
    assert_eq(a.entered, 1)
    assert_eq(a.exited, 0)

    sm.change_state(b)
    assert_eq(a.exited, 1, "Old state should be exited once")
    assert_eq(b.entered, 1, "New state should be entered once")
    assert_eq(sm.current_state, b)


func test_process_frame_transitions_when_state_returns_new_state() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var a := SpyState.new()
    var b := SpyState.new()
    sm.add_child(a)
    sm.add_child(b)

    sm.change_state(a)

    a.return_on_frame = b
    sm._process(0.016)

    assert_eq(a.frame_calls, 1, "Should call process_frame on current state")
    assert_eq(a.exited, 1, "Should exit old state during transition")
    assert_eq(b.entered, 1, "Should enter new state during transition")
    assert_eq(sm.current_state, b)


func test_process_frame_no_transition_when_null_returned() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var a := SpyState.new()
    sm.add_child(a)

    sm.change_state(a)

    a.return_on_frame = null
    sm._process(0.016)

    assert_eq(a.frame_calls, 1)
    assert_eq(a.exited, 0, "Should not exit when no transition requested")
    assert_eq(a.entered, 1, "Should not re-enter when no transition requested")
    assert_eq(sm.current_state, a)


func test_configuration_warning_when_no_states_exist() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var warnings := sm._get_configuration_warnings()

    assert_true(
        _warnings_contain(warnings, "no child states"),
        "Should warn when no C3State children exist"
    )


func test_configuration_warning_for_non_state_child() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var bad_child := Node.new()
    bad_child.name = "NotAState"
    sm.add_child(bad_child)

    var warnings := sm._get_configuration_warnings()

    assert_true(
        _warnings_contain(warnings, "NotAState"),
        "Should warn about non-C3State child nodes"
    )


func test_configuration_warning_when_starting_state_is_not_set() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    # Add at least one valid child state so we only trigger the starting_state warning.
    sm.add_child(C3State.new())

    # Leave sm.starting_state unset (null).
    var warnings := sm._get_configuration_warnings()

    assert_true(
        _warnings_contain(warnings, "Starting state is not set"),
        "Should warn when 'starting_state' is not assigned"
    )


func test_enter_receives_null_from_on_init() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var ctx := Node.new()
    add_child_autofree(ctx)

    var a := SpyState.new()
    sm.add_child(a)

    sm.starting_state = a
    sm.init(ctx)

    assert_eq(a.entered, 1)
    assert_null(a.last_from, "enter() should receive null when no previous state exists")


func test_enter_receives_previous_state_as_from() -> void:
    var sm := C3StateMachine.new()
    add_child_autofree(sm)

    var a := SpyState.new()
    var b := SpyState.new()
    sm.add_child(a)
    sm.add_child(b)

    sm.change_state(a)
    sm.change_state(b)

    assert_eq(b.last_from, a, "enter() should receive the outgoing state as 'from'")
