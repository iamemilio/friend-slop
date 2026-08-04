class_name PlayerMenu
extends PanelContainer

## Centered Tab menu: Inventory, Guide, and Spellbook (codex).

signal spell_selected(spell_id: String)

enum Tab {
	INVENTORY,
	GUIDE,
	SPELLBOOK,
}

## Spellbook internal pages (compat with old GuidePanel.Page naming for callers).
enum Page {
	MAIN,
	CODEX,
	DETAIL,
}

const GuideContentScript := preload("res://scripts/ui/guide_content.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")
const PlayerInventoryScript := preload("res://scripts/inventory/player_inventory.gd")
const InventorySlotButtonScript := preload("res://scripts/ui/inventory_slot_button.gd")

const _SPELL_BUTTON_FONT_COLOR := Color(0.88, 0.92, 1, 1)

var _loadout: Node
var _inventory: Node
var _tab: Tab = Tab.GUIDE
var _page: Page = Page.MAIN
var _selected_spell_id := ""
var _objective_lines: PackedStringArray = PackedStringArray()
var _inv_buttons: Array[Button] = []

@onready var _title_label: Label = $MarginContainer/VBox/Header/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBox/Header/SubtitleLabel
@onready var _tab_bar: TabBar = $MarginContainer/VBox/TabBar
@onready var _nav_row: HBoxContainer = $MarginContainer/VBox/NavRow
@onready var _back_button: Button = $MarginContainer/VBox/NavRow/BackButton
@onready var _inventory_page: VBoxContainer = $MarginContainer/VBox/InventoryPage
@onready var _inventory_grid: GridContainer = $MarginContainer/VBox/InventoryPage/InventoryGrid
@onready var _inventory_hint: Label = $MarginContainer/VBox/InventoryPage/InventoryHint
@onready var _guide_page: VBoxContainer = $MarginContainer/VBox/GuidePage
@onready var _hints_label: Label = $MarginContainer/VBox/GuidePage/HintsLabel
@onready var _objective_label: Label = $MarginContainer/VBox/GuidePage/ObjectiveLabel
@onready var _codex_page: VBoxContainer = $MarginContainer/VBox/CodexPage
@onready var _codex_hint_label: Label = $MarginContainer/VBox/CodexPage/CodexHintLabel
@onready var _spell_list_box: VBoxContainer = $MarginContainer/VBox/CodexPage/SpellListBox
@onready var _detail_page: VBoxContainer = $MarginContainer/VBox/DetailPage
@onready var _detail_title: Label = $MarginContainer/VBox/DetailPage/DetailTitle
@onready var _detail_body: Label = $MarginContainer/VBox/DetailPage/DetailBody


func _ready() -> void:
	visible = false
	set_process(false)
	_back_button.pressed.connect(_on_back_pressed)
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_build_inventory_slots()
	_show_tab(Tab.GUIDE)


func configure_loadout(loadout: Node) -> void:
	_loadout = loadout


func configure_inventory(inventory: Node) -> void:
	if (
		_inventory != null
		and _inventory.has_signal("inventory_changed")
		and _inventory.inventory_changed.is_connected(_refresh_inventory)
	):
		_inventory.inventory_changed.disconnect(_refresh_inventory)
	_inventory = inventory
	if _inventory != null and _inventory.has_signal("inventory_changed"):
		_inventory.inventory_changed.connect(_refresh_inventory)
	_refresh_inventory()


func _process(_delta: float) -> void:
	if not visible or _loadout == null:
		return
	if _tab != Tab.SPELLBOOK:
		return
	match _page:
		Page.CODEX:
			_refresh_codex_cooldown_labels()
		Page.DETAIL:
			_refresh_spell_detail()
		_:
			pass


func get_page() -> Page:
	return _page


func get_tab() -> Tab:
	return _tab


func is_codex_view() -> bool:
	return _tab == Tab.SPELLBOOK and (_page == Page.CODEX or _page == Page.DETAIL)


func reset_to_main() -> void:
	_show_tab(Tab.GUIDE)


func set_selected_spell_id(spell_id: String) -> void:
	_selected_spell_id = spell_id


func open_codex() -> void:
	_show_tab(Tab.SPELLBOOK)
	_page = Page.CODEX
	_refresh_codex_list()
	_update_content_visibility()


func open_inventory() -> void:
	_show_tab(Tab.INVENTORY)


func refresh(objective_lines: PackedStringArray) -> void:
	_objective_lines = objective_lines
	if _tab == Tab.GUIDE:
		_apply_main_view(_objective_lines)
	elif _tab == Tab.SPELLBOOK:
		match _page:
			Page.CODEX:
				_refresh_codex_list()
			Page.DETAIL:
				_refresh_spell_detail()
			_:
				pass
	elif _tab == Tab.INVENTORY:
		_refresh_inventory()


func _show_tab(tab: Tab) -> void:
	_tab = tab
	if _tab_bar.current_tab != int(tab):
		_tab_bar.set_block_signals(true)
		_tab_bar.current_tab = int(tab)
		_tab_bar.set_block_signals(false)
	match tab:
		Tab.INVENTORY:
			_title_label.text = "Inventory"
			_subtitle_label.text = "Drag items between slots. Press [Tab] to hide"
			_page = Page.MAIN
			_refresh_inventory()
		Tab.GUIDE:
			_title_label.text = "Guide"
			_subtitle_label.text = "Press [Tab] to hide"
			_page = Page.MAIN
			_apply_main_view(_objective_lines)
		Tab.SPELLBOOK:
			_title_label.text = "Spellbook"
			_subtitle_label.text = "Press [Tab] to hide"
			if _page != Page.DETAIL:
				_page = Page.CODEX
			if _page == Page.CODEX:
				_refresh_codex_list()
			else:
				_refresh_spell_detail()
	_update_content_visibility()


func _update_content_visibility() -> void:
	var show_detail := _tab == Tab.SPELLBOOK and _page == Page.DETAIL
	var show_codex := _tab == Tab.SPELLBOOK and _page == Page.CODEX
	_inventory_page.visible = _tab == Tab.INVENTORY
	_guide_page.visible = _tab == Tab.GUIDE
	_codex_page.visible = show_codex
	_detail_page.visible = show_detail
	_nav_row.visible = show_detail
	_tab_bar.visible = not show_detail
	set_process(visible and _tab == Tab.SPELLBOOK and (_page == Page.CODEX or _page == Page.DETAIL))


func _on_tab_changed(tab: int) -> void:
	_page = Page.MAIN
	_show_tab(tab as Tab)


func _apply_main_view(objective_lines: PackedStringArray) -> void:
	var view := GuideContentScript.build_view(objective_lines)
	_hints_label.text = str(view.get("hints", ""))
	_objective_label.text = str(view.get("objectives", ""))


func _build_inventory_slots() -> void:
	for child in _inventory_grid.get_children():
		child.queue_free()
	_inv_buttons.clear()
	for i in PlayerInventoryScript.SLOT_COUNT:
		var button: Button = InventorySlotButtonScript.new()
		_inventory_grid.add_child(button)
		if button.has_method("setup"):
			button.call("setup", _inventory, i)
		_inv_buttons.append(button)
	if _inventory_hint != null:
		_inventory_hint.text = "Drag items between slots. Slots 1–4 are the hotbar (keys 1–4)."


func _refresh_inventory() -> void:
	for button in _inv_buttons:
		if button.has_method("setup"):
			button.call("setup", _inventory, int(button.get("slot_index")))
		elif button.has_method("refresh"):
			button.set("inventory", _inventory)
			button.call("refresh")


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
		var label := GuideContentScript.codex_row_label(
			spell, spell_id, _remaining_cooldown_sec(spell_id)
		)
		_add_spell_button(spell_id, label)


func _refresh_codex_cooldown_labels() -> void:
	for child in _spell_list_box.get_children():
		if not child is Button:
			continue
		if not child.has_meta("spell_id"):
			continue
		var spell_id := str(child.get_meta("spell_id"))
		var spell := _resolve_spell(spell_id)
		(child as Button).text = GuideContentScript.codex_row_label(
			spell, spell_id, _remaining_cooldown_sec(spell_id)
		)


func _refresh_spell_detail() -> void:
	var spell := _resolve_spell(_selected_spell_id)
	var detail := GuideContentScript.build_spell_detail(
		spell, _remaining_cooldown_sec(_selected_spell_id)
	)
	_detail_title.text = str(detail.get("title", "Spell"))
	_detail_body.text = str(detail.get("body", ""))


func _remaining_cooldown_sec(spell_id: String) -> float:
	if _loadout == null or not _loadout.has_method("remaining_cooldown_sec"):
		return 0.0
	return float(_loadout.remaining_cooldown_sec(spell_id))


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
	button.set_meta("spell_id", spell_id)
	button.add_theme_color_override("font_color", _SPELL_BUTTON_FONT_COLOR)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_spell_button_pressed.bind(spell_id))
	_spell_list_box.add_child(button)


func _on_back_pressed() -> void:
	if _tab == Tab.SPELLBOOK and _page == Page.DETAIL:
		_page = Page.CODEX
		_refresh_codex_list()
		_update_content_visibility()


func _on_spell_button_pressed(spell_id: String) -> void:
	_selected_spell_id = spell_id
	spell_selected.emit(spell_id)
	_page = Page.DETAIL
	_refresh_spell_detail()
	_update_content_visibility()
