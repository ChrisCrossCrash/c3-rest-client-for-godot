# C3 Godot Utils
# v2.1.0
# File revision: 2026-02-09

extends CharacterBody3D
class_name C3FpsPlayer
## A minimal first-person player node for Godot 4.

@export_category("Movement")

@export var allow_running := true

## Horizontal movement speed in units per second.
@export var walk_speed := 5.0
@export var run_speed := 10.0

## Downward acceleration applied when the player is not on the floor in units/s^2.
##
## If set to `0.0`, the player will use the project's default 3D gravity
## (`physics/3d/default_gravity`) at runtime.
@export var gravity: float = 0.0

@export_category("Mouse Look")

## Mouse look sensitivity in radians per pixel.
@export var mouse_sensitivity := 0.0025

## Maximum vertical look angle from center, in degrees.
@export var max_look_angle := 89.0

@onready var head: Node3D = $Head

var _pitch := 0.0


func _ready() -> void:
    if gravity == 0.0:
        gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _rotate_camera(event.relative)


## Applies mouse-driven yaw and pitch rotation.
##
## `relative` is mouse motion in pixels.
func _rotate_camera(relative: Vector2) -> void:
    # Yaw
    rotate_y(-relative.x * mouse_sensitivity)

    # Pitch
    _pitch -= relative.y * mouse_sensitivity
    _pitch = clamp(
        _pitch,
        deg_to_rad(-max_look_angle),
        deg_to_rad(max_look_angle)
    )
    head.rotation.x = _pitch


## Applies gravity, movement input, and moves the character.
func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    _apply_movement()
    move_and_slide()


## Applies downward acceleration when the player is airborne.
func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta


## Applies horizontal movement based on input actions.
func _apply_movement() -> void:
    var input_dir := Input.get_vector(
        "move_left",
        "move_right",
        "move_forward",
        "move_backward"
    )

    var direction := transform.basis * Vector3(input_dir.x, 0, input_dir.y)

    var move_speed: float = walk_speed
    if allow_running and Input.is_action_pressed("move_run"):
        move_speed = run_speed

    if direction:
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
    else:
        velocity.x = move_toward(velocity.x, 0, move_speed)
        velocity.z = move_toward(velocity.z, 0, move_speed)
