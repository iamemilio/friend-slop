class_name SpellLog
extends RefCounted

## Logging helper for spell/STT code paths that must compile before autoloads init.


static func debug(tag: String, message: String) -> void:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tome: Node = loop.root.get_node_or_null("/root/TomeDebug")
		if tome != null and tome.has_method("log"):
			tome.call("log", tag, message)
			return
	print("[TomeDebug:%s] %s" % [tag, message])
