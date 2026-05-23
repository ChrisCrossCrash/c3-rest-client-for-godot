# C3 Godot Utils
# v2.5.0
# File revision: 2026-05-13

class_name C3Utils

const _MEDIA_KEYS := [
	KEY_VOLUMEDOWN,
	KEY_VOLUMEMUTE,
	KEY_VOLUMEUP,
	KEY_MEDIAPLAY,
	KEY_MEDIASTOP,
	KEY_MEDIAPREVIOUS,
	KEY_MEDIANEXT,
	KEY_MEDIARECORD,
]

const _MODIFIER_KEYS := [
	KEY_SHIFT,
	KEY_CTRL,
	KEY_ALT,
	KEY_META,
	KEY_CAPSLOCK,
	KEY_NUMLOCK,
	KEY_SCROLLLOCK,
]

const _MOUSE_WHEEL_BUTTONS := [
	MOUSE_BUTTON_WHEEL_UP,
	MOUSE_BUTTON_WHEEL_DOWN,
	MOUSE_BUTTON_WHEEL_LEFT,
	MOUSE_BUTTON_WHEEL_RIGHT,
]


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
static func clamp_cube_vector_to_unit_sphere(
	v: Vector3, deadzone: float = 0.0
) -> Vector3:
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
		(
			Input.get_action_raw_strength(positive_x)
			- Input.get_action_raw_strength(negative_x)
		),
		(
			Input.get_action_raw_strength(positive_y)
			- Input.get_action_raw_strength(negative_y)
		),
		(
			Input.get_action_raw_strength(positive_z)
			- Input.get_action_raw_strength(negative_z)
		)
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
## Excludes media keys and mouse wheel scrolls. Set include_modifiers to true
## to allow Shift/Ctrl/Alt/etc. alone to count as a key press.
static func is_any_key(event: InputEvent, include_modifiers := false) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return not _is_excluded_key(event.keycode, include_modifiers)
	if event is InputEventJoypadButton and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed:
		return not event.button_index in _MOUSE_WHEEL_BUTTONS
	return false


static func _is_excluded_key(keycode: int, include_modifiers: bool) -> bool:
	if keycode in _MEDIA_KEYS:
		return true
	return not include_modifiers and keycode in _MODIFIER_KEYS


## A hash-based set collection backed by a [Dictionary].[br][br]
##
## Stores unique values with O(1) average-case membership testing, insertion,
## and removal. Accepts [Array], [Dictionary] (uses keys), or another [HashSet]
## as an initializer or operand wherever an iterable is expected.[br][br]
##
## API mirrors Python's [code]set[/code] where practical.
class HashSet:
	var _data: Dictionary = {}

	## Creates a new [HashSet], optionally populated from [param iterable].[br][br]
	##
	## [param iterable] may be an [Array], [Dictionary] (uses keys), or another
	## [HashSet]. Omit the argument or pass [code]null[/code] for an empty set.
	func _init(iterable: Variant = null) -> void:
		if iterable != null:
			_update_from(iterable)

	# --- Core mutation ---

	## Adds [param value] to the set. Has no effect if [param value] is already present.
	func add(value: Variant) -> void:
		_data[value] = null

	## Removes [param value] from the set.[br][br]
	##
	## Pushes an error if [param value] is not present. Use [method discard]
	## for silent removal.
	func remove(value: Variant) -> void:
		if not _data.has(value):
			push_error("HashSet.remove(x): x not in set")
			return
		_data.erase(value)

	## Removes [param value] from the set if present; does nothing otherwise.
	func discard(value: Variant) -> void:
		_data.erase(value)

	## Removes and returns an arbitrary element from the set.[br][br]
	##
	## Pushes an error and returns [code]null[/code] if the set is empty.
	## Iteration order is not guaranteed.
	func pop() -> Variant:
		if _data.is_empty():
			push_error("pop from an empty set")
			return null
		var key = _data.keys()[0]
		_data.erase(key)
		return key

	## Removes all elements from the set.
	func clear() -> void:
		_data.clear()

	# --- Queries ---

	## Returns [code]true[/code] if [param value] is a member of the set.
	func has(value: Variant) -> bool:
		return _data.has(value)

	## Returns the number of elements in the set.
	func size() -> int:
		return _data.size()

	## Returns [code]true[/code] if the set contains no elements.
	func is_empty() -> bool:
		return _data.is_empty()

	## Returns a shallow copy of the set.
	func copy() -> HashSet:
		return HashSet.new(_data.keys())

	# --- Set algebra (non-mutating) ---

	## Returns a new [HashSet] containing all elements from both this set and [param other].
	func union(other: Variant) -> HashSet:
		var result := copy()
		result._update_from(other)
		return result

	## Returns a new [HashSet] containing only elements present in both this set and [param other].
	func intersection(other: Variant) -> HashSet:
		var other_set := _as_set(other)
		var result := HashSet.new()
		for value in _data.keys():
			if other_set.has(value):
				result.add(value)
		return result

	## Returns a new [HashSet] containing elements in this set that are not in [param other].
	func difference(other: Variant) -> HashSet:
		var other_set := _as_set(other)
		var result := HashSet.new()
		for value in _data.keys():
			if not other_set.has(value):
				result.add(value)
		return result

	## Returns a new [HashSet] containing elements in either set but not both.
	func symmetric_difference(other: Variant) -> HashSet:
		var other_set := _as_set(other)
		var result := HashSet.new()
		for value in _data.keys():
			if not other_set.has(value):
				result.add(value)
		for value in other_set.values():
			if not _data.has(value):
				result.add(value)
		return result

	# --- Set algebra (in-place) ---

	## Adds all elements from [param other] to this set in place.
	func update(other: Variant) -> void:
		_update_from(other)

	## Removes from this set all elements not found in [param other], in place.
	func intersection_update(other: Variant) -> void:
		var other_set := _as_set(other)
		for value in _data.keys():
			if not other_set.has(value):
				_data.erase(value)

	## Removes all elements found in [param other] from this set, in place.
	func difference_update(other: Variant) -> void:
		for value in _iter(other):
			_data.erase(value)

	## Updates this set in place, keeping only elements found in one set or the
	## other, but not both.
	func symmetric_difference_update(other: Variant) -> void:
		for value in _iter(other):
			if _data.has(value):
				_data.erase(value)
			else:
				_data[value] = null

	# --- Comparisons ---

	## Returns [code]true[/code] if every element of this set is in [param other].
	func issubset(other: Variant) -> bool:
		var other_set := _as_set(other)
		for value in _data.keys():
			if not other_set.has(value):
				return false
		return true

	## Returns [code]true[/code] if this set contains every element of [param other].
	func issuperset(other: Variant) -> bool:
		for value in _iter(other):
			if not _data.has(value):
				return false
		return true

	## Returns [code]true[/code] if this set shares no elements with [param other].
	func isdisjoint(other: Variant) -> bool:
		for value in _iter(other):
			if _data.has(value):
				return false
		return true

	## Returns [code]true[/code] if both sets contain exactly the same elements.
	func equals(other: HashSet) -> bool:
		if size() != other.size():
			return false
		return issubset(other)

	# --- Iteration support ---

	## Returns all elements of the set as an [Array]. Order is not guaranteed.
	func values() -> Array:
		return _data.keys()

	# --- Internal helpers ---

	func _update_from(iterable: Variant) -> void:
		for value in _iter(iterable):
			_data[value] = null

	func _iter(iterable: Variant) -> Array:
		# Accept HashSet, Array, Dictionary (uses keys), or anything iterable
		if iterable is HashSet:
			return iterable.values()
		elif iterable is Array:
			return iterable
		elif iterable is Dictionary:
			return iterable.keys()
		else:
			push_error("HashSet: expected iterable, got %s" % typeof(iterable))
			return []

	func _as_set(other: Variant) -> HashSet:
		if other is HashSet:
			return other
		return HashSet.new(other)

	func _to_string() -> String:
		return "HashSet(%s)" % str(_data.keys())
