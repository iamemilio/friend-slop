class_name SpellEffectApplier
extends Node

## Applies spell gameplay and visual effects locally or via multiplayer sync.

const SyncScript := preload("res://scripts/spells/spell_effect_sync.gd")


func apply_effect(player: CharacterBody3D, spell: SpellDefinition) -> void:
	if spell == null or player == null:
		return
	var params := SyncScript.build_params(spell, player)
	if params.is_empty():
		push_warning("SpellEffectApplier: unsupported spell '%s'" % spell.id)
		return
	SyncScript.apply(player, params)


func cast_spell(player: CharacterBody3D, spell: SpellDefinition) -> void:
	if spell == null or player == null:
		return
	var params := SyncScript.build_params(spell, player)
	if params.is_empty():
		push_warning("SpellEffectApplier: cannot cast unsupported spell '%s'" % spell.id)
		return
	if not GameState.is_multiplayer:
		SyncScript.apply(player, params)
		return
	if multiplayer.is_server():
		NetworkManager.broadcast_spell_cast(multiplayer.get_unique_id(), spell.id, params)
	else:
		NetworkManager.request_spell_cast.rpc_id(1, spell.id, params)


func apply_synced_cast(
	player: CharacterBody3D,
	spell: SpellDefinition,
	params: Dictionary
) -> void:
	if player == null or spell == null:
		return
	if params.is_empty():
		params = SyncScript.build_params(spell, player)
	if params.is_empty():
		return
	SyncScript.apply(player, params)


static func apply_synced_spell_cast_on_peer(
	players_root: Node,
	spell_registry: SpellRegistry,
	caster_peer_id: int,
	spell_id: String,
	params: Dictionary
) -> bool:
	var player := players_root.get_node_or_null(str(caster_peer_id)) as CharacterBody3D
	if player == null:
		return false
	var spell := spell_registry.get_spell(spell_id)
	if spell == null:
		return false
	var applier := player.get_effect_applier() as SpellEffectApplier
	if applier == null:
		return false
	applier.apply_synced_cast(player, spell, params)
	return true
