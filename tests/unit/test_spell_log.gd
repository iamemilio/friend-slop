class_name TestSpellLog
extends RefCounted

## Guards against scene-tree access from worker threads in spell/STT logging.

const SpellLogScript := preload("res://scripts/spells/spell_log.gd")


func run() -> int:
	var failures := 0
	failures += _test_debug_from_worker_avoids_scene_tree()
	return failures


static func _worker_debug() -> void:
	SpellLogScript.debug("TestWorker", "thread-safe log")


func _test_debug_from_worker_avoids_scene_tree() -> int:
	SpellLogScript.last_used_scene_tree = false
	var thread := Thread.new()
	if thread.start(_worker_debug) != OK:
		push_error("Expected SpellLog worker thread to start")
		return 1
	thread.wait_to_finish()
	if SpellLogScript.last_used_scene_tree:
		push_error("SpellLog.debug must not access the scene tree from a worker thread")
		return 1
	return 0
