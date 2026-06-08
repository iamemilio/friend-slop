extends Node

## Dev logging for tome / spell casting. Toggle via TomeDebug.enabled in the editor or at runtime.

var enabled := true


func log(tag: String, message: String) -> void:
	if not enabled:
		return
	print("[TomeDebug:%s] %s" % [tag, message])
