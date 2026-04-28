# C3 Godot Utils
# v2.0.0
# File revision: 2026-01-18

class_name C3Utils


## Clamps a 3D input vector from a cube-shaped range to a unit sphere.[br][br]
##
## The input vector is assumed to come from a cube domain (each component in the
## range [-1, 1]). The vector’s direction is preserved while its magnitude is
## processed radially:[br]
## - If the vector’s length is below `deadzone`, Vector3.ZERO is returned.[br]
## - If the length exceeds 1.0, the vector is normalized to the unit sphere.[br]
## - Otherwise, the magnitude is smoothly rescaled so that values just above
##   `deadzone` map to near-zero output and full strength is reached at length 1.0.[br][br]
##
## This function applies radial deadzone handling and length clamping, but does
## not perform a true cube-to-sphere remapping. Diagonal directions are preserved,
## and only the vector’s magnitude is modified.
static func clamp_cube_vector_to_unit_sphere(v: Vector3, deadzone: float = 0.0) -> Vector3:
    var v_len := v.length()

    # Avoid 0/0 and match "less than or equal" deadzone behavior.
    if v_len <= deadzone:
        return Vector3.ZERO

    elif v_len > 1.0:
        # We are clamping to the unit sphere.
        # No need to consider deadzone here.
        return v / v_len

    # Rescale magnitude from (deadzone → 1) to (0 → 1)
    var scaled_len := inverse_lerp(deadzone, 1.0, v_len)
    return v * (scaled_len / v_len)


## Reads pairs of input actions and returns a 3D movement vector.[br][br]
##
## Each axis (X, Y, Z) is defined by a negative and positive input action.
## Raw input strengths are combined to form a Vector3 representing the
## intended movement direction and magnitude.[br][br]
##
## If the vector magnitude is less than or equal to `deadzone`,
## the function returns Vector3.ZERO.[br][br]
##
## For magnitudes between `deadzone` and 1.0, the vector is rescaled so that
## movement begins smoothly immediately after the deadzone threshold and
## reaches full strength at maximum input, while preserving direction.[br][br]
##
## If the magnitude exceeds 1.0, the vector is normalized to length 1.0.
static func get_vector3(
    negative_x: StringName, positive_x: StringName,
    negative_y: StringName, positive_y: StringName,
    negative_z: StringName, positive_z: StringName,
    deadzone: float = 0.1
) -> Vector3:
    var v := Vector3(
        Input.get_action_raw_strength(positive_x) - Input.get_action_raw_strength(negative_x),
        Input.get_action_raw_strength(positive_y) - Input.get_action_raw_strength(negative_y),
        Input.get_action_raw_strength(positive_z) - Input.get_action_raw_strength(negative_z)
    )
    return clamp_cube_vector_to_unit_sphere(v, deadzone)


## Formats a duration value (in seconds) into a human-readable time string.[br][br]
##
## Converts a floating-point duration expressed in seconds into a formatted
## time string suitable for HUDs, split displays, and results screens.
## The output uses minutes and seconds, includes milliseconds,
## and automatically adds an hours component when the duration exceeds
## one hour. Negative values are always represented with a leading - sign.
## Positive values are prepended with a "+" if `sign_positive` is true.[br][br]
##
## Examples:[br]
## * 65.432                   → "01:05.432"[br]
## * -3.01                    → "-00:03.010"[br]
## * format_time(1.234, true) → "+00:01.234"
static func format_time(seconds: float, sign_positive: bool = false) -> String:
    # Determine sign prefix
    var sign_prefix := ""
    if seconds < 0.0:
        sign_prefix = "-"
    elif sign_positive and seconds > 0.0:
        sign_prefix = "+"

    # Work with absolute magnitude
    var total_ms: int = floori(abs(seconds) * 1000.0)

    var ms: int = total_ms % 1000

    var total_s: int = floori(total_ms / 1000.0)
    var secs: int = total_s % 60

    var total_min: int = floori(total_s / 60.0)
    var minutes: int = total_min % 60

    var hours: int = floori(total_min / 60.0)

    if hours > 0:
        return sign_prefix + "%02d:%02d:%02d.%03d" % [hours, minutes, secs, ms]
    else:
        return sign_prefix + "%02d:%02d.%03d" % [minutes, secs, ms]


## Returns true if the event is any key press, button press, or mouse click.
static func is_any_key(event: InputEvent) -> bool:
    return (
        event is InputEventKey and event.pressed and not event.echo
        or event is InputEventJoypadButton and event.pressed
        or event is InputEventMouseButton and event.pressed
    )
