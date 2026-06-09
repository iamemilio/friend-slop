class_name CharacterSetupPanel
extends Control

signal closed

var _selected_starting_node_id: String = ""
var _active_role: int = GameState.PlayerRole.APPRENTICE

@onready var _title_label: Label = $Panel/MarginContainer/VBox/TitleLabel
@onready var _role_section: HBoxContainer = $Panel/MarginContainer/VBox/RoleSection
@onready var _apprentice_role_button: Button = (
	$Panel/MarginContainer/VBox/RoleSection/ApprenticeRoleButton
)
@onready var _warden_role_button: Button = (
	$Panel/MarginContainer/VBox/RoleSection/WardenRoleButton
)
@onready var _skill_tree_options: VBoxContainer = $Panel/MarginContainer/VBox/SkillTreeOptions
@onready var _tree_name_label: Label = (
	$Panel/MarginContainer/VBox/SkillTreeOptions/TreeNameLabel
)
@onready var _skill_tree_view: SkillTreeView = (
	$Panel/MarginContainer/VBox/SkillTreeOptions/SkillTreeView
)
@onready var _done_button: Button = $Panel/MarginContainer/VBox/DoneButton
@onready var _back_button: Button = $Panel/MarginContainer/VBox/BackButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_apprentice_role_button.pressed.connect(_on_apprentice_role_pressed)
	_warden_role_button.pressed.connect(_on_warden_role_pressed)
	_done_button.pressed.connect(_on_done_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_skill_tree_view.starting_node_selected.connect(_on_starting_node_selected)
	NetworkManager.lobby_roles_changed.connect(_on_lobby_roles_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func open() -> void:
	if not NetworkManager.is_online():
		return
	_load_from_lobby()
	visible = true


func _tree_for_role(role: int) -> SkillTreeDefinition:
	if role == GameState.PlayerRole.WARDEN:
		return Binding.DEFAULT_WARDEN_TREE
	return Binding.DEFAULT_FIREMAGE_TREE


func _refresh_skill_tree_view() -> void:
	var tree := _tree_for_role(_active_role)
	_tree_name_label.text = tree.display_name
	_skill_tree_view.configure(
		tree,
		_selected_starting_node_id,
		SpellDisplayNames.build_catalog()
	)


func _load_from_lobby() -> void:
	var peer_id := multiplayer.get_unique_id()
	var role := NetworkManager.lobby.get_role(peer_id)
	var config := PlayerCharacterConfig.from_dict(NetworkManager.lobby.get_character_config(peer_id))
	_apply_role_ui(role)
	_selected_starting_node_id = config.binding.starting_node_id
	if not _tree_for_role(role).is_valid_starting_node(_selected_starting_node_id):
		_selected_starting_node_id = _tree_for_role(role).get_default_starting_node_id()
	_refresh_skill_tree_view()


func _apply_role_ui(role: int) -> void:
	_active_role = role
	var is_apprentice := role == GameState.PlayerRole.APPRENTICE
	_skill_tree_options.visible = true
	SelectionStyle.style_choice(_apprentice_role_button, is_apprentice)
	SelectionStyle.style_choice(_warden_role_button, not is_apprentice)
	_title_label.text = "Configure Apprentice" if is_apprentice else "Configure Warden"


func _read_config_from_ui() -> PlayerCharacterConfig:
	var peer_id := multiplayer.get_unique_id()
	var role := NetworkManager.lobby.get_role(peer_id)
	var config := PlayerCharacterConfig.create_default(role)
	config.binding.starting_node_id = _selected_starting_node_id
	return config


func _on_apprentice_role_pressed() -> void:
	NetworkManager.request_lobby_role(GameState.PlayerRole.APPRENTICE)


func _on_warden_role_pressed() -> void:
	NetworkManager.request_lobby_role(GameState.PlayerRole.WARDEN)


func _on_starting_node_selected(node_id: String) -> void:
	_selected_starting_node_id = node_id


func _on_lobby_roles_changed() -> void:
	if not visible:
		return
	var role := NetworkManager.lobby.get_role(multiplayer.get_unique_id())
	var tree := _tree_for_role(role)
	if not tree.is_valid_starting_node(_selected_starting_node_id):
		_selected_starting_node_id = tree.get_default_starting_node_id()
	_apply_role_ui(role)
	_refresh_skill_tree_view()


func _on_done_pressed() -> void:
	NetworkManager.request_character_config(_read_config_from_ui().to_dict())
	_close_panel()


func _on_back_pressed() -> void:
	_close_panel()


func _close_panel() -> void:
	visible = false
	closed.emit()
