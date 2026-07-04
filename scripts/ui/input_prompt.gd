class_name InputPrompt
extends RefCounted

## Builds HUD prompts from InputMap so rebinding updates the displayed key.


static func action_label(action_name: String, fallback: String = "?") -> String:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event == null:
			continue
		var text := _event_label(event)
		if not text.is_empty():
			return text
	return fallback


static func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := (
			key_event.physical_keycode
			if key_event.physical_keycode != 0
			else key_event.keycode
		)
		if code != 0:
			return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
	return _shorten_as_text(event.as_text())


static func _shorten_as_text(text: String) -> String:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return ""
	var dash_idx := trimmed.find(" - ")
	if dash_idx >= 0:
		trimmed = trimmed.substr(0, dash_idx).strip_edges()
	var paren_idx := trimmed.find(" (")
	if paren_idx >= 0:
		trimmed = trimmed.substr(0, paren_idx).strip_edges()
	return trimmed


static func bracket(action_name: String, fallback: String = "?") -> String:
	return "[%s]" % action_label(action_name, fallback)


static func with_action(action_name: String, message: String, fallback: String = "?") -> String:
	return "%s %s" % [message, bracket(action_name, fallback)]
