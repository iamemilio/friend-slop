extends Node


func _ready() -> void:
	print("scene run editor=", OS.has_feature("editor"), " debug=", OS.has_feature("debug"))
	print("VoskRecognizer available: ", ClassDB.class_exists("VoskRecognizer"))
	get_tree().quit(0 if ClassDB.class_exists("VoskRecognizer") else 1)
