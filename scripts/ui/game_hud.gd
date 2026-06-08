class_name GameHud
extends CanvasLayer

## In-game HUD: interaction prompt, spellbook, casting overlay.

const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")

var _spellbook: Node
var _selected_spell_id: String = ""
var _spellbook_open := false
var _active_spell: Resource
var _from_tome := false
var _coaching_countdown := 0.0
var _cooldown_strip: VBoxContainer
var _cooldown_rows: Dictionary = {}
var _cooldown_blocked_until: float = 0.0
var _cooldown_blocked_spell_id: String = ""

@onready var prompt_label: Label = $MarginContainer/PromptLabel
@onready var spellbook_panel: PanelContainer = $SpellbookPanel
@onready var spell_list: ItemList = $SpellbookPanel/MarginContainer/VBox/SpellList
@onready var spellbook_hint: Label = $SpellbookPanel/MarginContainer/VBox/HintLabel
@onready var casting_panel: PanelContainer = $CastingPanel
@onready var casting_title: Label = $CastingPanel/MarginContainer/VBox/TitleLabel
@onready var casting_words: Label = $CastingPanel/MarginContainer/VBox/WordsLabel
@onready var casting_guide: Label = $CastingPanel/MarginContainer/VBox/GuideLabel
@onready var casting_status: Label = $CastingPanel/MarginContainer/VBox/StatusLabel
@onready var mic_level_bar: ProgressBar = $CastingPanel/MarginContainer/VBox/MicLevelBar
@onready var casting_feedback: Label = $CastingPanel/MarginContainer/VBox/FeedbackLabel
@onready var casting_detail: Label = $CastingPanel/MarginContainer/VBox/DetailLabel


func _ready() -> void:
	add_to_group("game_hud")
	prompt_label.text = ""
	spellbook_panel.visible = false
	casting_panel.visible = false
	mic_level_bar.min_value = 0.0
	mic_level_bar.max_value = 1.0
	mic_level_bar.value = 0.0
	spell_list.item_selected.connect(_on_spell_selected)
	_setup_cooldown_strip()


func configure(spellbook: Node, casting_session: Node = null) -> void:
	_spellbook = spellbook
	if _spellbook != null and _spellbook.has_signal("spell_learned"):
		_spellbook.spell_learned.connect(_on_spell_learned)
	if casting_session != null and casting_session.has_signal("listen_level_changed"):
		casting_session.listen_level_changed.connect(update_listen_level)
	if casting_session != null and casting_session.has_signal("listen_coaching_changed"):
		casting_session.listen_coaching_changed.connect(update_listen_coaching)
	if casting_session != null and casting_session.has_signal("tome_retry_tick"):
		casting_session.tome_retry_tick.connect(update_tome_coaching_countdown)


func set_interaction_prompt(text: String) -> void:
	prompt_label.text = text


func toggle_spellbook() -> void:
	_spellbook_open = not _spellbook_open
	spellbook_panel.visible = _spellbook_open
	if _spellbook_open:
		_refresh_spell_list()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func close_spellbook() -> void:
	if not _spellbook_open:
		return
	_spellbook_open = false
	spellbook_panel.visible = false


func is_spellbook_open() -> bool:
	return _spellbook_open


func get_selected_spell_id() -> String:
	return _selected_spell_id


func show_casting_state(
	state: String,
	spell: Resource,
	from_tome: bool = false,
	free_cast: bool = false
) -> void:
	if spell == null and not free_cast:
		if not _from_tome:
			casting_panel.visible = false
		return
	if free_cast:
		_show_free_cast_state(state)
		return
	var def := spell as SpellDefinitionScript
	if def == null:
		casting_panel.visible = false
		return
	_from_tome = from_tome
	_active_spell = spell
	casting_panel.visible = true
	if from_tome:
		casting_title.text = "Tome: Learning %s" % def.display_name
		casting_words.text = 'Incantation: "%s"' % def.get_incantation_text()
		casting_guide.text = def.get_tome_lesson_text()
	else:
		casting_title.text = "Casting: %s" % def.display_name
		casting_words.text = 'Incantation: "%s"' % def.get_incantation_text()
		var guide_parts: PackedStringArray = []
		var timing: String = def.get_timing_guide_text()
		var pitch: String = def.get_pitch_guide_text()
		if not timing.is_empty():
			guide_parts.append(timing)
		if not pitch.is_empty():
			guide_parts.append(pitch)
		casting_guide.text = "\n".join(guide_parts)
	var leave_hint := "\n\nPress [F] to leave the tome." if from_tome else ""
	match state:
		"arming":
			casting_status.text = "Get ready..."
			casting_detail.text = def.get_listen_coaching_text() + leave_hint
			mic_level_bar.visible = false
			casting_feedback.text = ""
		"listening":
			casting_status.text = "Speak now!"
			casting_detail.text = def.get_listen_coaching_text() + leave_hint
			mic_level_bar.visible = true
			mic_level_bar.value = 0.0
			casting_feedback.text = ""
		"validating":
			casting_status.text = "Checking your cast..."
			casting_detail.text = ""
			mic_level_bar.visible = false
		"coaching":
			casting_status.text = "Not quite — adjust and try again"
			mic_level_bar.visible = false
		_:
			casting_status.text = ""
			if not from_tome:
				casting_detail.text = ""
			mic_level_bar.visible = false
	if state != "coaching":
		casting_feedback.text = ""


func _show_free_cast_state(state: String) -> void:
	_from_tome = false
	casting_panel.visible = true
	casting_title.text = "Voice cast"
	casting_words.text = "Say any spell you've learned"
	casting_guide.text = _format_known_incantations()
	match state:
		"arming":
			casting_status.text = "Get ready..."
			casting_detail.text = casting_guide.text
			mic_level_bar.visible = false
			casting_feedback.text = ""
		"listening":
			casting_status.text = "Speak now!"
			mic_level_bar.visible = true
			mic_level_bar.value = 0.0
			casting_feedback.text = ""
		"validating":
			casting_status.text = "Identifying your spell..."
			casting_detail.text = ""
			mic_level_bar.visible = false
		_:
			casting_status.text = ""
			casting_detail.text = ""
			mic_level_bar.visible = false


func _format_known_incantations() -> String:
	if _spellbook == null:
		return ""
	var known: Array[String] = _spellbook.get_known_spell_ids()
	if known.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for spell_id in known:
		var spell: Resource = _spellbook.get_spell_definition(spell_id)
		var def := spell as SpellDefinitionScript
		if def != null:
			parts.append('"%s" (%s)' % [def.get_incantation_text(), def.display_name])
	return "Known: " + ", ".join(parts)


func update_listen_level(level: float) -> void:
	if not casting_panel.visible:
		return
	mic_level_bar.value = clampf(level / 0.08, 0.0, 1.0)


func update_listen_coaching(message: String) -> void:
	if not casting_panel.visible or message.is_empty():
		return
	if _from_tome:
		casting_detail.text = message + "\n\nPress [F] to leave the tome."
	else:
		casting_detail.text = message


func hide_casting() -> void:
	casting_panel.visible = false
	casting_feedback.text = ""
	casting_detail.text = ""
	_active_spell = null
	_from_tome = false
	_coaching_countdown = 0.0
	_cooldown_blocked_spell_id = ""
	_cooldown_blocked_until = 0.0


func show_cast_feedback(result: RefCounted, from_tome: bool = false) -> void:
	if result == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	if result.has_method("get_coaching_lines"):
		lines = result.get_coaching_lines(from_tome)
	elif result.has_method("get_feedback_lines"):
		lines = result.get_feedback_lines()
	if lines.is_empty():
		return
	mic_level_bar.visible = false
	casting_feedback.text = lines[0]
	if lines.size() > 1:
		casting_detail.text = "\n".join(lines.slice(1))
	else:
		casting_detail.text = ""
	if from_tome:
		_coaching_countdown = 2.0


func show_spell_learned(spell: Resource, validation: RefCounted = null) -> void:
	var def := spell as SpellDefinitionScript
	if def == null:
		return
	_from_tome = false
	_active_spell = spell
	casting_panel.visible = true
	casting_title.text = "Spell Learned!"
	casting_words.text = def.display_name
	casting_guide.text = def.get_learned_confirmation_text()
	casting_status.text = "The tome's magic is yours now."
	casting_feedback.text = 'Incantation: "%s"' % def.get_incantation_text()
	if validation != null and validation.has_method("get_speech_match_line") \
			and not validation.heard_text.is_empty():
		casting_detail.text = validation.get_speech_match_line()
	else:
		casting_detail.text = ""
	mic_level_bar.visible = false


func show_cast_success(spell: Resource, validation: RefCounted = null) -> void:
	var def := spell as SpellDefinitionScript
	if def == null:
		return
	_from_tome = false
	_active_spell = spell
	casting_panel.visible = true
	casting_title.text = "Cast successful: %s" % def.display_name
	casting_words.text = 'Incantation: "%s"' % def.get_incantation_text()
	casting_guide.text = ""
	casting_status.text = "Success!"
	casting_feedback.text = def.get_cast_success_text()
	if validation != null and validation.has_method("get_speech_match_line") \
			and not validation.heard_text.is_empty():
		casting_detail.text = validation.get_speech_match_line()
	else:
		casting_detail.text = ""
	mic_level_bar.visible = false


func track_spell_cooldown(spell_id: String, total_sec: float) -> void:
	if _spellbook == null or total_sec <= 0.0:
		return
	_ensure_cooldown_row(spell_id, total_sec)


func show_cooldown_blocked(spell: Resource, remaining_sec: float) -> void:
	var def := spell as SpellDefinitionScript
	if def == null or remaining_sec <= 0.0:
		return
	_cooldown_blocked_spell_id = def.id
	_cooldown_blocked_until = Time.get_ticks_msec() / 1000.0 + remaining_sec
	track_spell_cooldown(def.id, def.cooldown_sec)
	casting_panel.visible = true
	casting_title.text = "%s on cooldown" % def.display_name
	casting_words.text = 'Incantation: "%s"' % def.get_incantation_text()
	casting_status.text = "Wait before casting again"
	casting_feedback.text = "Cooldown: %.1fs remaining" % remaining_sec
	casting_detail.text = "Press [F] to try a different spell."
	mic_level_bar.visible = false
	mic_level_bar.value = 1.0 - clampf(remaining_sec / def.cooldown_sec, 0.0, 1.0)
	mic_level_bar.visible = true


func update_tome_coaching_countdown(seconds_left: float) -> void:
	if not _from_tome or not casting_panel.visible:
		return
	_coaching_countdown = seconds_left
	var countdown_line := "Next attempt in %.0fs..." % maxf(0.0, seconds_left)
	if casting_detail.text.is_empty():
		casting_detail.text = countdown_line
	elif not casting_detail.text.contains("Next attempt"):
		casting_detail.text += "\n" + countdown_line
	else:
		var parts: PackedStringArray = casting_detail.text.split("\n")
		var kept: PackedStringArray = PackedStringArray()
		for part in parts:
			if not str(part).begins_with("Next attempt"):
				kept.append(str(part))
		kept.append(countdown_line)
		casting_detail.text = "\n".join(kept)


func _refresh_spell_list() -> void:
	var previous_selection := _selected_spell_id
	spell_list.clear()
	if _spellbook == null:
		_selected_spell_id = ""
		return

	var known: Array[String] = _spellbook.get_known_spell_ids()
	if known.is_empty():
		_selected_spell_id = ""
		spell_list.add_item("(No spells learned yet)")
		spellbook_hint.text = "Find floating tomes in the maze."
		return

	spellbook_hint.text = "Select a spell, then press [F] to cast by voice."
	var selected_index := -1
	for spell_id in known:
		var spell: Resource = _spellbook.get_spell_definition(spell_id)
		var label: String = spell_id
		if spell != null:
			var def := spell as SpellDefinitionScript
			if def != null:
				label = def.display_name
		var cd: float = _spellbook.cooldown_remaining(spell_id)
		if cd > 0.0:
			label += " (%.1fs)" % cd
		spell_list.add_item(label)
		var item_index := spell_list.item_count - 1
		spell_list.set_item_metadata(item_index, spell_id)
		if spell_id == previous_selection:
			selected_index = item_index

	if selected_index >= 0:
		spell_list.select(selected_index)
		_selected_spell_id = previous_selection
	elif spell_list.item_count > 0:
		spell_list.select(0)
		_selected_spell_id = str(spell_list.get_item_metadata(0))
	else:
		_selected_spell_id = ""


func _on_spell_selected(index: int) -> void:
	if index < 0:
		return
	_selected_spell_id = str(spell_list.get_item_metadata(index))


func _on_spell_learned(spell_id: String) -> void:
	_selected_spell_id = spell_id
	if _spellbook_open:
		_refresh_spell_list()


func _process(_delta: float) -> void:
	if _spellbook_open and _spellbook != null:
		_refresh_spell_list_if_cooling()
	_update_cooldown_strip()
	_update_cooldown_blocked_overlay()


func _setup_cooldown_strip() -> void:
	_cooldown_strip = VBoxContainer.new()
	_cooldown_strip.name = "CooldownStrip"
	_cooldown_strip.add_theme_constant_override("separation", 4)
	add_child(_cooldown_strip)
	_cooldown_strip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_cooldown_strip.offset_left = -220.0
	_cooldown_strip.offset_top = 12.0
	_cooldown_strip.offset_right = -16.0
	_cooldown_strip.offset_bottom = 12.0
	_cooldown_strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cooldown_strip.visible = false


func _ensure_cooldown_row(spell_id: String, total_sec: float) -> void:
	if _spellbook == null:
		return
	var remaining: float = _spellbook.cooldown_remaining(spell_id)
	if remaining <= 0.0:
		_remove_cooldown_row(spell_id)
		return

	var row: Dictionary
	if _cooldown_rows.has(spell_id):
		row = _cooldown_rows[spell_id]
	else:
		var container := HBoxContainer.new()
		container.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.custom_minimum_size = Vector2(72, 0)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.92, 0.88, 1, 1))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(120, 14)
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.show_percentage = false
		container.add_child(label)
		container.add_child(bar)
		_cooldown_strip.add_child(container)
		row = {"container": container, "label": label, "bar": bar, "total_sec": total_sec}
		_cooldown_rows[spell_id] = row

	var spell: Resource = _spellbook.get_spell_definition(spell_id)
	var display_name: String = spell_id
	if spell != null:
		var def := spell as SpellDefinitionScript
		if def != null:
			display_name = def.display_name
	var bar_ref: ProgressBar = row["bar"]
	var total: float = float(row.get("total_sec", total_sec))
	var fill: float = 1.0 - clampf(remaining / total, 0.0, 1.0)
	bar_ref.value = fill
	row["label"].text = "%s %.1fs" % [display_name, remaining]
	_cooldown_strip.visible = not _cooldown_rows.is_empty()


func _remove_cooldown_row(spell_id: String) -> void:
	if not _cooldown_rows.has(spell_id):
		return
	var row: Dictionary = _cooldown_rows[spell_id]
	var container: Node = row["container"]
	container.queue_free()
	_cooldown_rows.erase(spell_id)
	_cooldown_strip.visible = not _cooldown_rows.is_empty()


func _update_cooldown_strip() -> void:
	if _spellbook == null:
		return
	for spell_id in _cooldown_rows.keys():
		if _spellbook.cooldown_remaining(spell_id) <= 0.0:
			_remove_cooldown_row(spell_id)
			continue
		var row: Dictionary = _cooldown_rows[spell_id]
		var remaining: float = _spellbook.cooldown_remaining(spell_id)
		var total: float = float(row.get("total_sec", 1.0))
		row["bar"].value = 1.0 - clampf(remaining / total, 0.0, 1.0)
		var spell: Resource = _spellbook.get_spell_definition(spell_id)
		var display_name: String = spell_id
		if spell != null:
			var def := spell as SpellDefinitionScript
			if def != null:
				display_name = def.display_name
		row["label"].text = "%s %.1fs" % [display_name, remaining]


func _update_cooldown_blocked_overlay() -> void:
	if _cooldown_blocked_spell_id.is_empty() or _spellbook == null:
		return
	var remaining: float = _spellbook.cooldown_remaining(_cooldown_blocked_spell_id)
	if remaining <= 0.0:
		_cooldown_blocked_spell_id = ""
		_cooldown_blocked_until = 0.0
		return
	if not casting_panel.visible:
		return
	var spell: Resource = _spellbook.get_spell_definition(_cooldown_blocked_spell_id)
	var def := spell as SpellDefinitionScript
	if def == null:
		return
	if casting_title.text.ends_with("on cooldown"):
		casting_feedback.text = "Cooldown: %.1fs remaining" % remaining
		mic_level_bar.value = 1.0 - clampf(remaining / def.cooldown_sec, 0.0, 1.0)


func _refresh_spell_list_if_cooling() -> void:
	for spell_id in _spellbook.get_known_spell_ids():
		if _spellbook.cooldown_remaining(spell_id) > 0.0:
			_refresh_spell_list()
			return
