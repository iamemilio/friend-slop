extends RefCounted

const SpellBookScript := preload("res://scripts/spells/spell_book.gd")
const SpellDefinitionScript := preload("res://scripts/spells/spell_definition.gd")


func run() -> int:
	var failures := 0
	failures += _test_unknown_spell_cannot_cast()
	failures += _test_freshly_learned_spell_can_cast()
	failures += _test_cooldown_blocks_cast()
	return failures


func _make_book() -> SpellBookScript:
	var book := SpellBookScript.new()
	var lumos := SpellDefinitionScript.new()
	lumos.id = "lumos"
	lumos.cooldown_sec = 2.0
	book.configure([lumos])
	return book


func _test_unknown_spell_cannot_cast() -> int:
	var book := _make_book()
	if book.can_cast("lumos"):
		push_error("Expected unknown spell to be on cooldown/unavailable")
		return 1
	return 0


func _test_freshly_learned_spell_can_cast() -> int:
	var book := _make_book()
	book.learn("lumos")
	if not book.can_cast("lumos"):
		push_error("Expected freshly learned spell to be castable")
		return 1
	return 0


func _test_cooldown_blocks_cast() -> int:
	var book := _make_book()
	book.learn("lumos")
	book.mark_cast("lumos")
	if book.can_cast("lumos"):
		push_error("Expected spell to be on cooldown immediately after cast")
		return 1
	if book.cooldown_remaining("lumos") <= 0.0:
		push_error("Expected positive cooldown remaining after cast")
		return 1
	return 0
