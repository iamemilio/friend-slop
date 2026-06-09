extends RefCounted

const SpellBookScript := preload("res://scripts/spells/spell_book.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")


func run() -> int:
	var failures := 0
	failures += _test_unknown_spell_cannot_cast()
	failures += _test_freshly_learned_spell_can_cast()
	failures += _test_cooldown_blocks_cast()
	failures += _test_active_effect_blocks_cast()
	return failures


func _make_book() -> SpellBookScript:
	var book := SpellBookScript.new()
	var show_me := SpellDefinitionScript.new()
	show_me.id = "show_me"
	show_me.cooldown_sec = 2.0
	book.configure([show_me])
	return book


func _test_unknown_spell_cannot_cast() -> int:
	var book := _make_book()
	if book.can_cast("show_me"):
		push_error("Expected unknown spell to be on cooldown/unavailable")
		return 1
	return 0


func _test_freshly_learned_spell_can_cast() -> int:
	var book := _make_book()
	book.learn("show_me")
	if not book.can_cast("show_me"):
		push_error("Expected freshly learned spell to be castable")
		return 1
	return 0


func _test_cooldown_blocks_cast() -> int:
	var book := _make_book()
	book.learn("show_me")
	book.mark_cast("show_me")
	if book.can_cast("show_me"):
		push_error("Expected spell to be on cooldown immediately after cast")
		return 1
	if book.cooldown_remaining("show_me") <= 0.0:
		push_error("Expected positive cooldown remaining after cast")
		return 1
	return 0


func _test_active_effect_blocks_cast() -> int:
	var book := _make_book()
	book.learn("show_me")
	book.begin_active_effect("show_me", 5.0)
	if book.can_cast("show_me"):
		push_error("Expected active spell effect to block casting")
		return 1
	if book.cooldown_remaining("show_me") > 0.0:
		push_error("Expected cooldown to stay idle while spell effect is active")
		return 1
	if book.effect_active_remaining("show_me") <= 0.0:
		push_error("Expected active effect timer after begin_active_effect")
		return 1
	return 0
