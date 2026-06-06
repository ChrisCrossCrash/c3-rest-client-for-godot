class_name SoundVisualizer
extends Node3D

enum AnimationState { AMPLITUDE_DRIVEN, PULSING, IDLE }

## Base radius of the sphere mesh at zero amplitude.
@export var base_scale := 1.0
## How much the sphere radius grows per unit of smoothed amplitude.
@export var amplitude_scaling := 1.0
## How much smoothed amplitude contributes to the shader noise displacement.
@export var amplitude_noise_contrib := 0.5
## Speed at which the shader noise pattern moves.
@export var noise_movement_speed := 20.0
## Exponential smoothing rate for amplitude (per second). Higher = snappier.
@export var amplitude_smoothing := 10.0
## Multiplier applied to smoothed amplitude when setting spot light energy.
@export var amplitude_light_factor := 2.0
## Exponential smoothing rate for light color transitions (per second). Higher = snappier.
@export var light_color_smoothing := 10.0
## Speed of the pulse cycle (radians/sec) in PULSING state. 2π ≈ one pulse per second.
@export var pulse_speed := 3.0
## Peak amplitude of the pulse (0–1) in PULSING state.
@export var pulse_intensity := 0.3

var _amplitude_target := 0.0
var _amplitude_smoothed := 0.0
var _light_color := Color("#29ffd8")
var _animation_state := AnimationState.IDLE

@onready var sphere_mesh: MeshInstance3D = $SphereMesh
@onready var spot_light: SpotLight3D = $SpotLight3D


func _process(delta: float) -> void:
	match _animation_state:
		AnimationState.AMPLITUDE_DRIVEN:
			# Target is set externally via set_amplitude().
			pass
		AnimationState.PULSING:
			var pulse := sin(Time.get_ticks_msec() / 1000.0 * pulse_speed) * 0.5 + 0.5
			_amplitude_target = pulse * pulse_intensity
		AnimationState.IDLE:
			_amplitude_target = 0.0
	_update_amplitude(delta)
	_update_sphere_mesh()
	_update_spot_light(delta)


func set_amplitude(amplitude: float) -> void:
	_amplitude_target = amplitude


func set_light_color(color: Color) -> void:
	_light_color = color


func set_animation_state(state: AnimationState) -> void:
	_animation_state = state


func _update_amplitude(delta: float) -> void:
	_amplitude_smoothed = lerpf(
		_amplitude_smoothed, _amplitude_target, 1.0 - exp(-amplitude_smoothing * delta)
	)


func _update_spot_light(delta: float) -> void:
	spot_light.light_energy = 0.3 + _amplitude_smoothed * amplitude_light_factor
	spot_light.light_color = spot_light.light_color.lerp(
		_light_color, 1.0 - exp(-light_color_smoothing * delta)
	)


func _update_sphere_mesh() -> void:
	var mesh_scale := base_scale + _amplitude_smoothed * amplitude_scaling
	sphere_mesh.scale = Vector3(mesh_scale, mesh_scale, mesh_scale)

	var mat := sphere_mesh.get_active_material(0) as ShaderMaterial
	mat.set_shader_parameter(
		"noise_strength",
		_amplitude_smoothed * amplitude_noise_contrib
	)
	mat.set_shader_parameter(
		"movement_speed",
		noise_movement_speed
	)
