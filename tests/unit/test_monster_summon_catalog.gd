class_name TestMonsterSummonCatalog
extends RefCounted

const CatalogScript := preload("res://scripts/ui/book/monster/monster_summon_catalog.gd")


func run() -> int:
	var failures := 0
	failures += _test_has_pages()
	failures += _test_entry_fields()
	return failures


func _test_has_pages() -> int:
	if CatalogScript.entry_count() < 1:
		push_error("Expected at least one summon book page")
		return 1
	return 0


func _test_entry_fields() -> int:
	var entry := CatalogScript.entry_at(0)
	if str(entry.get("display_name", "")).is_empty():
		push_error("Expected display_name on catalog entry")
		return 1
	if str(entry.get("scene_path", "")).is_empty():
		push_error("Expected scene_path on catalog entry")
		return 1
	return 0
