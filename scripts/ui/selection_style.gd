class_name SelectionStyle
extends RefCounted

## Shared selected/unselected styling for lobby toggle buttons.

static func style_choice(button: Button, selected: bool) -> void:
	button.disabled = false
	button.toggle_mode = false
	if selected:
		button.add_theme_color_override("font_color", Color(0.95, 0.98, 1))
		button.add_theme_color_override("font_hover_color", Color(0.95, 0.98, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.95, 0.98, 1))
		button.add_theme_stylebox_override(
			"normal",
			_make_stylebox(Color(0.22, 0.42, 0.62, 1), Color(0.55, 0.9, 1, 1))
		)
		button.add_theme_stylebox_override(
			"hover",
			_make_stylebox(Color(0.26, 0.48, 0.68, 1), Color(0.65, 0.95, 1, 1))
		)
		button.add_theme_stylebox_override(
			"pressed",
			_make_stylebox(Color(0.22, 0.42, 0.62, 1), Color(0.55, 0.9, 1, 1))
		)
	else:
		button.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
		button.add_theme_color_override("font_hover_color", Color(0.85, 0.92, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.85, 0.92, 1))
		button.add_theme_stylebox_override(
			"normal",
			_make_stylebox(Color(0.14, 0.11, 0.2, 1), Color(0.28, 0.34, 0.44, 1))
		)
		button.add_theme_stylebox_override(
			"hover",
			_make_stylebox(Color(0.18, 0.14, 0.24, 1), Color(0.4, 0.55, 0.72, 1))
		)
		button.add_theme_stylebox_override(
			"pressed",
			_make_stylebox(Color(0.18, 0.14, 0.24, 1), Color(0.4, 0.55, 0.72, 1))
		)


static func _make_stylebox(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
