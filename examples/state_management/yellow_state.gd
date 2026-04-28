extends BaseLightState
class_name YellowState


func enter(from: C3State) -> void:
    super(from)  # The super class sets the color of the text.
    demo.label.text = "YELLOW"


func process_frame(delta: float) -> BaseLightState:
    elapsed_time += delta

    if elapsed_time >= duration:
        elapsed_time = 0.0
        return red_state

    return null
