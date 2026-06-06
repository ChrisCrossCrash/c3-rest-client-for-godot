class_name UIOverlay
extends CanvasLayer

const FADE_DURATION := 0.4

@onready var toast_label: Label = $ToastLabel

var _toast_tween: Tween


func show_toast(
	msg: String,
	color := Color("white"),
	duration_s := 5.0
) -> void:
	if _toast_tween:
		_toast_tween.kill()

	toast_label.text = msg
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 0.0
	toast_label.show()

	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_label, "modulate:a", 1.0, FADE_DURATION)
	_toast_tween.tween_interval(duration_s)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, FADE_DURATION)
	await _toast_tween.finished
	toast_label.hide()
