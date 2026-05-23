extends Node
class_name TrafficLightDemo

@onready var state_machine: C3StateMachine = $StateMachine
@onready var label: Label = $TrafficLightLabel

func _ready() -> void:
	state_machine.init(self)
