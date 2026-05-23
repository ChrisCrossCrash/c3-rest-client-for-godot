class_name BaseLightState
extends C3State

@export var color := Color(0.5, 0.5, 0.5)
@export var duration := 2.0
@export var red_state: BaseLightState
@export var yellow_state: BaseLightState
@export var green_state: BaseLightState

var elapsed_time := 0.0

# We could just use `context`, but it's nice to have a typed `demo` interface.
var demo: TrafficLightDemo:
	get: return context as TrafficLightDemo

func enter(_from: C3State) -> void:
	# Even if you override this method, you can still get this behavior by
	# calling `super()` on the inheriting class.
	demo.label.add_theme_color_override("font_color", color)

func exit() -> void:
	pass

func process_input(_event: InputEvent) -> BaseLightState:
	return null

func process_frame(_delta: float) -> BaseLightState:
	return null

func process_physics(_delta: float) -> BaseLightState:
	return null
