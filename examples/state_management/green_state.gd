extends BaseLightState
class_name GreenState

func enter(from: C3State) -> void:
    super(from)  # The super class sets the color of the text.
    demo.label.text = "GREEN"

func process_frame(delta: float) -> BaseLightState:
    elapsed_time += delta

    if elapsed_time >= duration:
        elapsed_time = 0.0
        return yellow_state

    return null
