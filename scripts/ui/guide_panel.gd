class_name GuidePanel
extends PanelContainer

## Tab-toggled side panel for controls, objectives, and spell codex reference.

signal spell_selected(spell_id: String)

enum Page {
	MAIN,
	CODEX,
	DETAIL,
}

const GuideContentScript := preload("res://scripts/ui/guide_content.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")

const _SPELL_BUTTON_FONT_COLOR := Color(0.88, 0.92, 1, 1)

var _loadout: Node
var _page: Page = Page.MAIN
var _selected_spell_id := ""
var _objective_lines: PackedStringArray = PackedStringArray()

@onready var _main_header: VBoxContainer = $MarginContainer/VBox/MainHeader
@onready var _nav_row: HBoxContainer = $MarginContainer/VBox/NavRow
@onready var _back_button: Button = $MarginContainer/VBox/NavRow/BackButton
@onready var _main_page: VBoxContainer = $MarginContainer/VBox/MainPage
@onready var _hints_label: Label = $MarginContainer/VBox/MainPage/HintsLabel
@onready var _objective_label: Label = $MarginContainer/VBox/MainPage/ObjectiveLabel
@onready var _codex_open_button: Button = $MarginContainer/VBox/MainPage/CodexOpenButton
@onready var _codex_page: VBoxContainer = $MarginContainer/VBox/CodexPage
@onready var _codex_hint_label: Label = $MarginContainer/VBox/CodexPage/CodexHintLabel
@onready var _spell_list_box: VBoxContainer = $MarginContainer/VBox/CodexPage/SpellListBox
@onready var _detail_page: VBoxContainer = $MarginContainer/VBox/DetailPage
@onready var _detail_title: Label = $MarginContainer/VBox/DetailPage/DetailTitle
@onready var _detail_body: Label = $MarginContainer/VBox/DetailPage/DetailBody


func _ready() -> void:
	visible = false
	_codex_open_button.pressed.connect(_on_codex_open_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_show_page(Page.MAIN)


func configure_loadout(loadout: Node) -> void:
	_loadout = loadout


func get_page() -> Page:
	return _page


func is_codex_view() -> bool:
	return _page == Page.CODEX or _page == Page.DETAIL


func reset_to_main() -> void:
	_page = Page.MAIN
	_show_page(Page.MAIN)


func set_selected_spell_id(spell_id: String) -> void:
	_selected_spell_id = spell_id


func open_codex() -> void:
	_show_page(Page.CODEX)
	_refresh_codex_list()


func refresh(objective_lines: PackedStringArray) -> void:
	_objective_lines = objective_lines
	match _page:
		Page.MAIN:
			_apply_main_view(_objective_lines)
		Page.CODEX:
			_refresh_codex_list()
		Page.DETAIL:
			_refresh_spell_detail()


func _apply_main_view(objective_lines: PackedStringArray) -> void:
	var view := GuideContentScript.build_view(objective_lines)
	_hints_label.text = str(view.get("hints", ""))
	_objective_label.text = str(view.get("objectives", ""))


func _refresh_codex_list() -> void:
	_clear_spell_list()
	var spell_ids := GuideContentScript.codex_spell_ids(_loadout)
	if spell_ids.is_empty():
		_add_codex_message(GuideContentScript.CODEX_EMPTY_LIST_LABEL)
		_codex_hint_label.text = GuideContentScript.codex_empty_hint()
		return

	_codex_hint_label.text = GuideContentScript.codex_list_hint()
	if _selected_spell_id.is_empty() or _selected_spell_id not in spell_ids:
		_selected_spell_id = spell_ids[0]
		spell_selected.emit(_selected_spell_id)

	for spell_id in spell_ids:
		var spell := _resolve_spell(spell_id)
		var label := GuideContentScript.codex_row_label(spell, spell_id)
		_add_spell_button(spell_id, label)


func _refresh_spell_detail() -> void:
	var spell := _resolve_spell(_selected_spell_id)
	var detail := GuideContentScript.build_spell_detail(spell)
	_detail_title.text = str(detail.get("title", "Spell"))
	_detail_body.text = str(detail.get("body", ""))


func _resolve_spell(spell_id: String) -> SpellDefinitionScript:
	if _loadout == null or not _loadout.has_method("get_spell_definition"):
		return null
	return _loadout.get_spell_definition(spell_id) as SpellDefinitionScript


func _clear_spell_list() -> void:
	for child in _spell_list_box.get_children():
		child.queue_free()


func _add_codex_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.92, 1))
	label.add_theme_font_size_override("font_size", 14)
	_spell_list_box.add_child(label)


func _add_spell_button(spell_id: String, label: String) -> void:
	var button := Button.new()
	button.text = label
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", _SPELL_BUTTON_FONT_COLOR)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_spell_button_pressed.bind(spell_id))
	_spell_list_box.add_child(button)


func _show_page(page: Page) -> void:
	_page = page
	var is_main := page == Page.MAIN
	_main_header.visible = is_main
	_nav_row.visible = not is_main
	_main_page.visible = is_main
	_codex_page.visible = page == Page.CODEX
	_detail_page.visible = page == Page.DETAIL


func _on_codex_open_pressed() -> void:
	open_codex()


func _on_back_pressed() -> void:
	match _page:
		Page.CODEX:
			_show_page(Page.MAIN)
			_apply_main_view(_objective_lines)
		Page.DETAIL:
			_show_page(Page.CODEX)
			_refresh_codex_list()


func _on_spell_button_pressed(spell_id: String) -> void:
	_selected_spell_id = spell_id
	spell_selected.emit(spell_id)
	_show_page(Page.DETAIL)
	_refresh_spell_detail()
