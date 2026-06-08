class_name SpellSttConfig
extends RefCounted

## File-based STT setup checks (safe on the main game thread without loading gdvosk).

const GDEXTENSION_PATH := "res://addons/gdvosk/gdvosk.gdextension"
const MODEL_SEARCH_PATHS: Array[String] = [
	"res://addons/gdvosk/model",
	"res://models/vosk",
	"user://vosk-model",
]


static func is_configured() -> bool:
	return FileAccess.file_exists(GDEXTENSION_PATH) and not find_model_path().is_empty()


static func get_setup_issue() -> String:
	if not FileAccess.file_exists(GDEXTENSION_PATH):
		return (
			"Speech recognition not installed (gdvosk). "
			+ "Enable Voice Stub in Settings (ESC) for testing, "
			+ "or add the gdvosk addon under addons/gdvosk."
		)
	if find_model_path().is_empty():
		return (
			"Vosk speech model not found. "
			+ "Download a small English model from alphacephei.com/vosk/models "
			+ "and place it in res://models/vosk/."
		)
	return ""


static func get_runtime_issue() -> String:
	var setup_issue := get_setup_issue()
	if not setup_issue.is_empty():
		return setup_issue
	if not GdvoskAdapter.is_available():
		if OS.has_feature("editor"):
			return (
				"gdvosk is not loaded in the Godot editor. "
				+ "Run tools/setup_gdvosk.ps1, fully quit Godot, then reopen the project. "
				+ "Check the Output panel at startup for GDExtension errors."
			)
		return (
			"gdvosk is not loaded. Run tools/setup_gdvosk.ps1, "
			+ "then restart the game."
		)
	if not GdvoskAdapter.is_model_loaded():
		var loader_status: String = _speech_stt_loader_status()
		if loader_status.is_empty():
			return "Speech model is not loaded yet."
		return loader_status
	return ""


static func _speech_stt_loader_status() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return ""
	var loader: Node = tree.root.get_node_or_null("SpeechSttLoader")
	if loader == null:
		return ""
	return str(loader.call("get_status"))


static func find_model_path() -> String:
	return GdvoskAdapter.find_model_path()
