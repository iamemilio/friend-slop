class_name PlayableCharacter
extends CharacterBody3D

## Base playable character: movement, camera, spells, and optional wand/trail in derived scenes.

## Player body/head render layer — wand lights use a world-only mask and skip this layer.
const PLAYER_SELF_VISUAL_LAYER := WorldVisualLayers.PLAYER_SELF

const WALK_SPEED := 3.0
const SPRINT_SPEED := 5.0
const JUMP_VELOCITY := 2.5
const MOUSE_SENSITIVITY := 0.002
const INTERACT_RANGE_SQ := 9.0
const PLAYER_MIN_SEPARATION := 0.55
const BODY_RADIUS := 0.20
const HEAD_RADIUS := 0.16
const BODY_CENTER_Y := BODY_RADIUS
const HEAD_CENTER_Y := BODY_RADIUS * 2.0 + HEAD_RADIUS
const COLLISION_WALL_PADDING := 0.08
const BODY_COLLISION_RADIUS := BODY_RADIUS + COLLISION_WALL_PADDING

const FireballProjectileScript := preload("res://scripts/spells/fireball_projectile.gd")
const InputPromptScript := preload("res://scripts/ui/input_prompt.gd")
const WorldVisualLayers := preload("res://scripts/world_visual_layers.gd")

@export var player_index: int = 0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _character_color: Color = Color.WHITE
var _spell_loadout: Node
var _casting_session: SpellCastingSession
var _game_hud: CanvasLayer
var _effect_applier: Node
var _speed_boost_multiplier: float = 1.0
var _speed_boost_timer: float = 0.0
var _wand: PlayerWand
var _casting_lmb_held := false

@onready var head: Node3D = %Head
@onready var camera_pivot: Node3D = %CameraPivot
@onready var spell_loadout: Node = %CharacterSpellLoadout
@onready var casting_session: SpellCastingSession = %SpellCastingSession
@onready var effect_applier: Node = %SpellEffectApplier
@onready var _view_camera: Camera3D = %FirstPersonCamera
@onready var _body_mesh: MeshInstance3D = %Body
@onready var _head_mesh: MeshInstance3D = %HeadMesh
@onready var _body_collision: CollisionShape3D = %CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	floor_block_on_wall = false
	floor_snap_length = 0.15
	safe_margin = 0.04
	_wand = get_node_or_null("Head/CameraPivot/Wand") as PlayerWand
	if _wand == null:
		_wand = get_node_or_null("Head/CameraPivot/FirstPersonCamera/Wand") as PlayerWand
	_configure_collision()
	_character_color = GameState.get_snail_color(player_index)
	_apply_character_color(_character_color)
	_setup_view_camera()


func _setup_view_camera() -> void:
	if _uses_local_view():
		_view_camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_view_camera.queue_free()


func _uses_local_view() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


func _configure_collision() -> void:
	var body_capsule := CapsuleShape3D.new()
	body_capsule.radius = BODY_COLLISION_RADIUS
	var bottom_y := BODY_CENTER_Y - BODY_RADIUS
	var top_y := HEAD_CENTER_Y + HEAD_RADIUS
	var total_height := top_y - bottom_y
	body_capsule.height = maxf(0.08, total_height - body_capsule.radius * 2.0)
	_body_collision.shape = body_capsule
	_body_collision.position.y = bottom_y + body_capsule.radius + body_capsule.height * 0.5


func initialize_player(index: int) -> void:
	player_index = index
	_character_color = GameState.get_snail_color(player_index)
	_apply_character_color(_character_color)
	_on_player_initialized()


func _on_player_initialized() -> void:
	pass


func configure_interaction(
	spell_loadout_ref: Node,
	casting_session_ref: SpellCastingSession,
	game_hud: CanvasLayer,
	effect_applier_ref: Node
) -> void:
	_spell_loadout = spell_loadout_ref
	_casting_session = casting_session_ref
	_game_hud = game_hud
	_effect_applier = effect_applier_ref
	if _casting_session != null:
		if not _casting_session.state_changed.is_connected(_on_cast_session_state_changed):
			_casting_session.state_changed.connect(_on_cast_session_state_changed)
		if not _casting_session.listen_level_changed.is_connected(_on_cast_listen_level_changed):
			_casting_session.listen_level_changed.connect(_on_cast_listen_level_changed)
		if not _casting_session.cast_succeeded.is_connected(_on_wand_cast_succeeded):
			_casting_session.cast_succeeded.connect(_on_wand_cast_succeeded)
		if not _casting_session.cast_failed.is_connected(_on_wand_cast_failed):
			_casting_session.cast_failed.connect(_on_wand_cast_failed)


func get_spell_loadout() -> Node:
	return spell_loadout


func get_casting_session() -> SpellCastingSession:
	return casting_session


func get_effect_applier() -> Node:
	return effect_applier


func apply_speed_boost(duration: float, multiplier: float) -> void:
	_speed_boost_multiplier = multiplier
	_speed_boost_timer = duration


func set_flashlight_enabled(active: bool) -> void:
	if _wand != null:
		_wand.set_flashlight_enabled(active)


func set_flame_glow_enabled(active: bool) -> void:
	if _wand != null:
		_wand.set_flame_glow_enabled(active)


func launch_fireball() -> void:
	launch_fireball_from_params(_aim_fireball_origin(), _aim_fireball_direction())


func launch_fireball_from_params(origin: Vector3, direction: Vector3) -> void:
	var world := get_tree().current_scene
	if world == null:
		world = get_parent()
	FireballProjectileScript.spawn(world, origin, direction.normalized())


func get_wand_cast_origin() -> Vector3:
	if _wand != null:
		return _wand.get_cast_origin()
	return _head_aim_origin()


func get_wand_cast_direction() -> Vector3:
	if _wand != null:
		return _wand.get_cast_direction()
	return _camera_aim_direction()


func get_snail_color() -> Color:
	return _character_color


func _camera_aim_direction() -> Vector3:
	return -camera_pivot.global_transform.basis.z.normalized()


func _head_aim_origin() -> Vector3:
	return head.global_position + _camera_aim_direction() * 0.6 + Vector3(0.0, 0.1, 0.0)


func _aim_fireball_direction() -> Vector3:
	return get_wand_cast_direction()


func _aim_fireball_origin() -> Vector3:
	return get_wand_cast_origin()


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera_pivot.rotation.x = clampf(
			camera_pivot.rotation.x,
			deg_to_rad(-70.0),
			deg_to_rad(70.0)
		)

	if event.is_action_pressed("spellbook"):
		if _casting_session != null \
				and (_casting_session.is_active() or _casting_session.is_tome_teaching()):
			return
		if _game_hud != null and _game_hud.has_method("toggle_spellbook"):
			_game_hud.toggle_spellbook()

	if event.is_action_pressed("interact"):
		_try_interact()

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_wand_button_pressed()
		else:
			_on_wand_button_released()


func _on_cast_session_state_changed(state: String, _spell: SpellDefinition) -> void:
	if _wand == null:
		return
	var armed := (
		state == SpellCastingSession.STATE_ARMING
		or state == SpellCastingSession.STATE_LISTENING
		or state == SpellCastingSession.STATE_VALIDATING
	)
	_wand.set_armed(armed)


func _on_cast_listen_level_changed(level: float) -> void:
	if _wand != null:
		_wand.set_listen_level(level)


func _on_wand_cast_succeeded(
	spell: SpellDefinition,
	mode: String,
	_validation: CastValidationResult
) -> void:
	if _wand == null or mode != "cast":
		return
	_wand.play_cast_success(spell)


func _on_wand_cast_failed(
	_spell: SpellDefinition,
	_reason: String,
	_partial: CastValidationResult
) -> void:
	if _wand == null or _casting_session == null:
		return
	if _casting_session.is_tome_teaching():
		return
	_wand.play_fizzle()



func _separate_from_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node == self or not node is CharacterBody3D:
			continue

		var other: CharacterBody3D = node as CharacterBody3D
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = Vector3(1.0, 0.0, 0.0)
		var distance: float = away.length()
		if distance >= PLAYER_MIN_SEPARATION:
			continue
		global_position += away.normalized() * (PLAYER_MIN_SEPARATION - distance)


func _apply_character_color(color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	material.emission_enabled = true
	material.emission = color * 0.25
	material.emission_energy_multiplier = 0.8
	_body_mesh.material_override = material
	_body_mesh.layers = PLAYER_SELF_VISUAL_LAYER
	_body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var head_material := material.duplicate()
	head_material.albedo_color = color.lightened(0.08)
	head_material.emission = head_material.albedo_color * 0.25
	_head_mesh.material_override = head_material
	_head_mesh.layers = PLAYER_SELF_VISUAL_LAYER
	_head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _try_interact() -> void:
	TomeDebug.log("Player", "F pressed — try_interact")
	if _casting_session != null and _casting_session.is_active():
		return

	if _try_tome_teaching_interact():
		return

	var objective := _find_delivery_objective()
	if objective != null and objective.try_interact(self):
		return

	var interactable: Interactable = _find_nearest_interactable()
	if interactable != null:
		interactable.interact(self)
		return

	TomeDebug.log("Player", "no interactable in range")


func is_carrying_relic() -> bool:
	var objective := _find_delivery_objective()
	return objective != null and objective.is_carrier(self)


func stop_casting_for_relic_carry() -> void:
	if _casting_session == null:
		return
	if _casting_session.is_tome_teaching():
		_casting_session.end_tome_teaching()
	elif _casting_session.is_active():
		_casting_session.cancel()
	_casting_lmb_held = false
	if _game_hud != null and _game_hud.has_method("hide_casting"):
		_game_hud.hide_casting()


func _on_wand_button_pressed() -> void:
	if not is_multiplayer_authority():
		return
	if is_carrying_relic():
		stop_casting_for_relic_carry()
		return
	if _casting_session != null and _casting_session.is_tome_teaching():
		return
	_casting_lmb_held = true
	if _casting_session != null and _casting_session.is_active():
		_casting_session.cancel()
		return
	_try_free_cast()


func _on_wand_button_released() -> void:
	if not is_multiplayer_authority():
		return
	if is_carrying_relic():
		return
	if not _casting_lmb_held:
		return
	_casting_lmb_held = false
	if _casting_session == null:
		return
	if not _casting_session.is_free_cast() or not _casting_session.is_active():
		return
	_casting_session.release_wand_hold()


func _try_tome_teaching_interact() -> bool:
	if _casting_session == null or not _casting_session.is_tome_teaching():
		return false
	var tome: TomeInteractable = _find_nearest_tome()
	if tome == null or not tome.can_interact(self):
		return false
	tome.interact(self)
	return true


func _try_free_cast() -> bool:
	if is_carrying_relic():
		return false
	if _spell_loadout == null or _casting_session == null:
		return false
	var candidates: Array[SpellDefinition] = _spell_loadout.get_known_spells()
	if candidates.is_empty():
		return false
	_casting_session.start_free_cast(candidates)
	return true


func _find_nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Interactable:
			continue
		var interactable := node as Interactable
		if not interactable.can_interact(self):
			continue
		var dist := global_position.distance_squared_to(interactable.global_position)
		if dist < best_dist and dist <= INTERACT_RANGE_SQ:
			best_dist = dist
			best = interactable
	return best


func _find_nearest_tome() -> TomeInteractable:
	var best: TomeInteractable = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is TomeInteractable:
			continue
		var tome := node as TomeInteractable
		if not tome.can_interact(self):
			continue
		var dist := global_position.distance_squared_to(tome.global_position)
		if dist < best_dist and dist <= INTERACT_RANGE_SQ:
			best_dist = dist
			best = tome
	return best


func _find_delivery_objective() -> DeliveryObjective:
	for node in get_tree().get_nodes_in_group("delivery_objective"):
		if node is DeliveryObjective:
			return node
	return null


func _update_interaction_prompt() -> void:
	if _game_hud == null or not _game_hud.has_method("set_interaction_prompt"):
		return
	if _casting_session != null and _casting_session.is_tome_teaching():
		_game_hud.set_interaction_prompt(
			InputPromptScript.with_action("interact", "Leave tome")
		)
		return
	if _casting_session != null and _casting_session.is_active():
		_game_hud.set_interaction_prompt("")
		return
	var objective := _find_delivery_objective()
	if objective != null:
		var objective_prompt := objective.get_interaction_prompt(self)
		if not objective_prompt.is_empty():
			_game_hud.set_interaction_prompt(objective_prompt)
			return
	var interactable: Interactable = _find_nearest_interactable()
	if interactable != null:
		_game_hud.set_interaction_prompt(interactable.get_prompt())
		return
	_game_hud.set_interaction_prompt(_default_cast_prompt())


func _default_cast_prompt() -> String:
	return ""


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	if _speed_boost_timer > 0.0:
		_speed_boost_timer -= delta
		if _speed_boost_timer <= 0.0:
			_speed_boost_multiplier = 1.0

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (head.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := (SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED)
	speed *= _speed_boost_multiplier
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	_separate_from_players()
	_update_interaction_prompt()
