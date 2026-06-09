class_name SkillTreeView
extends Control

## Scrollable skill tree with a left detail sidebar for hovered/selected nodes.

signal starting_node_selected(node_id: String)

const NODE_MIN_SIZE := Vector2(96, 56)
const COLUMN_SEPARATION := 8
const KIND_COLORS := {
	"spell": Color(0.55, 0.82, 1.0),
	"stat": Color(0.72, 0.92, 0.62),
	"passive": Color(0.86, 0.72, 1.0),
}

var _definition: SkillTreeDefinition
var _selected_starting_id: String = ""
var _hovered_node_id: String = ""
var _focused_node_id: String = ""
var _spell_display_names: Dictionary = {}
var _spell_descriptions: Dictionary = {}
var _node_cards: Dictionary = {}

@onready var _detail_root: VBoxContainer = $Body/DetailSidebar/DetailRoot
@onready var _tree_root: VBoxContainer = $Body/TreeScroll/TreeRoot


func configure(
	definition: SkillTreeDefinition,
	selected_starting_id: String,
	spell_display_names: Dictionary = {}
) -> void:
	_definition = definition
	_selected_starting_id = selected_starting_id
	_spell_display_names = spell_display_names
	_spell_descriptions = SpellDisplayNames.build_descriptions()
	_rebuild_tree()
	_focus_node(_selected_starting_id)


func set_selected_starting_node(node_id: String) -> void:
	_selected_starting_id = node_id
	_focus_node(node_id)


func _rebuild_tree() -> void:
	for child in _tree_root.get_children():
		child.queue_free()
	_node_cards.clear()
	if _definition == null:
		_show_detail_placeholder()
		return
	var columns := _definition.get_layout_columns()
	for tier in range(_definition.get_max_tier() + 1):
		if tier > 0:
			_tree_root.add_child(_make_tier_connector())
		_tree_root.add_child(_make_tier_row(tier, columns))
	_refresh_node_styles()
	_update_detail_sidebar()


func _make_tier_connector() -> CenterContainer:
	var container := CenterContainer.new()
	container.custom_minimum_size = Vector2(0, 10)
	var label := Label.new()
	label.text = "↓"
	label.add_theme_color_override("font_color", Color(0.45, 0.55, 0.72, 0.9))
	container.add_child(label)
	return container


func _make_tier_row(tier: int, columns: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", COLUMN_SEPARATION)
	var tier_nodes := _definition.get_nodes_at_tier(tier)
	var nodes_by_column: Dictionary = {}
	for node in tier_nodes:
		nodes_by_column[node.column] = node
	for column in range(columns):
		if nodes_by_column.has(column):
			row.add_child(_make_node_card(nodes_by_column[column]))
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = NODE_MIN_SIZE
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(spacer)
	return row


func _make_node_card(node: SkillTreeNodeDefinition) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = NODE_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _make_card_stylebox(false, false))
	card.gui_input.connect(_on_node_card_input.bind(node.node_id))
	card.mouse_entered.connect(_on_node_hovered.bind(node.node_id))
	card.mouse_exited.connect(_on_node_unhovered.bind(node.node_id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)

	var title := Label.new()
	title.text = node.get_display_name()
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	content.add_child(title)

	if _definition.is_valid_starting_node(node.node_id):
		var badge := Label.new()
		badge.text = "Starting kit"
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", Color(0.62, 0.82, 1))
		content.add_child(badge)

	var item_labels := node.get_content_labels(_spell_display_names, _spell_descriptions)
	for label_text in item_labels:
		var item_label := Label.new()
		item_label.text = "• %s" % label_text
		item_label.add_theme_font_size_override("font_size", 12)
		item_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
		item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(item_label)

	_node_cards[node.node_id] = card
	return card


func _make_card_stylebox(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if selected:
		style.bg_color = Color(0.22, 0.42, 0.62, 1)
		style.border_color = Color(0.55, 0.9, 1, 1)
	elif hovered:
		style.bg_color = Color(0.18, 0.16, 0.28, 1)
		style.border_color = Color(0.5, 0.68, 0.92, 1)
	else:
		style.bg_color = Color(0.14, 0.11, 0.2, 1)
		style.border_color = Color(0.28, 0.34, 0.44, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _on_node_card_input(event: InputEvent, node_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_on_node_pressed(node_id)


func _on_node_hovered(node_id: String) -> void:
	_hovered_node_id = node_id
	_update_detail_sidebar()
	_refresh_node_styles()


func _on_node_unhovered(node_id: String) -> void:
	if _hovered_node_id == node_id:
		_hovered_node_id = ""
		_update_detail_sidebar()
		_refresh_node_styles()


func _on_node_pressed(node_id: String) -> void:
	_focused_node_id = node_id
	if _definition.is_valid_starting_node(node_id):
		_selected_starting_id = node_id
		starting_node_selected.emit(node_id)
	_refresh_node_styles()
	_update_detail_sidebar()


func _focus_node(node_id: String) -> void:
	_focused_node_id = node_id
	_refresh_node_styles()
	_update_detail_sidebar()


func _active_detail_node_id() -> String:
	if not _hovered_node_id.is_empty():
		return _hovered_node_id
	if not _focused_node_id.is_empty():
		return _focused_node_id
	return ""


func _update_detail_sidebar() -> void:
	for child in _detail_root.get_children():
		child.queue_free()
	var node_id := _active_detail_node_id()
	if node_id.is_empty() or _definition == null:
		_show_detail_placeholder()
		return
	var node := _definition.get_node(node_id)
	if node == null:
		_show_detail_placeholder()
		return
	_add_detail_heading(node, node_id)
	for item in node.get_content_items(_spell_display_names, _spell_descriptions):
		_detail_root.add_child(_make_detail_item_box(item))


func _show_detail_placeholder() -> void:
	var label := Label.new()
	label.text = "Hover or click a node to see what each item does."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74))
	_detail_root.add_child(label)


func _add_detail_heading(node: SkillTreeNodeDefinition, node_id: String) -> void:
	var heading := Label.new()
	heading.text = node.get_display_name()
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	_detail_root.add_child(heading)
	if not node.summary.is_empty():
		var summary := Label.new()
		summary.text = node.summary
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_font_size_override("font_size", 12)
		summary.add_theme_color_override("font_color", Color(0.68, 0.74, 0.84))
		_detail_root.add_child(summary)
	if _definition.is_valid_starting_node(node_id):
		var note := Label.new()
		note.text = "Pick this branch to start here."
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.58, 0.78, 1))
		_detail_root.add_child(note)


func _make_detail_item_box(item: Dictionary) -> PanelContainer:
	var kind := String(item.get("kind", "spell"))
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _make_detail_box_style(kind))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	box.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	margin.add_child(content)

	var kind_label := Label.new()
	kind_label.text = kind.capitalize()
	kind_label.add_theme_font_size_override("font_size", 10)
	kind_label.add_theme_color_override(
		"font_color",
		KIND_COLORS.get(kind, Color(0.7, 0.8, 0.9))
	)
	content.add_child(kind_label)

	var title := Label.new()
	title.text = String(item.get("label", ""))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1))
	content.add_child(title)

	var description := Label.new()
	description.text = String(item.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", Color(0.72, 0.78, 0.88))
	content.add_child(description)

	return box


func _make_detail_box_style(kind: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.96)
	var accent: Color = KIND_COLORS.get(kind, Color(0.45, 0.55, 0.72))
	style.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func _refresh_node_styles() -> void:
	for node_id_variant in _node_cards.keys():
		var node_id := String(node_id_variant)
		var card: PanelContainer = _node_cards[node_id_variant]
		var is_starting: bool = _definition.is_valid_starting_node(node_id)
		var is_selected: bool = node_id == _selected_starting_id
		var is_hovered: bool = node_id == _hovered_node_id
		var is_focused: bool = node_id == _focused_node_id
		var selected := is_starting and is_selected
		var hovered := is_hovered or (is_focused and not is_hovered)
		card.add_theme_stylebox_override("panel", _make_card_stylebox(selected, hovered))
