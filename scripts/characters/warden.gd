extends PlayableCharacter

## Maze Warden — larger silhouette, no wand; voice and spells use head aim.


const WARDEN_BODY_SCALE := 1.18
const WARDEN_COLLISION_SCALE := 1.12


func _ready() -> void:
	scale = Vector3.ONE * WARDEN_BODY_SCALE
	super._ready()


func _configure_collision() -> void:
	super._configure_collision()
	var shape := _body_collision.shape as CapsuleShape3D
	if shape != null:
		shape.radius *= WARDEN_COLLISION_SCALE
		shape.height *= WARDEN_COLLISION_SCALE


func _apply_character_color(color: Color) -> void:
	var warden_tint := Color(
		color.r * 0.35 + 0.08,
		color.g * 0.2 + 0.04,
		color.b * 0.45 + 0.12
	)
	super._apply_character_color(warden_tint)
	var body_mat := _body_mesh.material_override as StandardMaterial3D
	if body_mat != null:
		body_mat.roughness = 0.85
		body_mat.emission = warden_tint * 0.15


func _default_cast_prompt() -> String:
	if _spell_loadout != null and _spell_loadout.has_known_spells():
		return "Hold [LMB] to channel · Spell codex [B]"
	return ""
