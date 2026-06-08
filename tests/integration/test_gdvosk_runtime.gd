class_name TestGdvoskRuntime
extends RefCounted

## Optional runtime STT checks when the gdvosk extension is loaded.
## Skipped in CI (run_checks.py disables the extension to avoid native crashes).

const GdvoskAdapterScript := preload("res://scripts/spells/gdvosk_adapter.gd")
const SpellSttConfigScript := preload("res://scripts/spells/spell_stt_config.gd")

func run() -> int:
	if not GdvoskAdapterScript.is_available():
		print("Skipping gdvosk runtime tests (extension not loaded).")
		return 0
	if not SpellSttConfigScript.is_configured():
		print("Skipping gdvosk runtime tests (model or extension files missing).")
		return 0

	var failures := 0
	failures += _test_manifest_valid_when_installed()
	failures += _test_extension_loaded_when_available()
	failures += _test_model_loads()
	failures += _test_transcribe_does_not_crash()
	return failures


func _test_manifest_valid_when_installed() -> int:
	if not FileAccess.file_exists(GdvoskExtensionConfig.GDEXTENSION_PATH):
		return 0
	var issue := GdvoskExtensionConfig.validate_installed_manifest()
	if not issue.is_empty():
		push_error("Installed gdvosk.gdextension failed validation: %s" % issue)
		return 1
	return 0


func _test_extension_loaded_when_available() -> int:
	if not FileAccess.file_exists(GdvoskExtensionConfig.GDEXTENSION_PATH):
		return 0
	if not GdvoskExtensionConfig.is_extension_loaded():
		push_error(
			"gdvosk files are installed but VoskRecognizer is not registered. "
			+ "Fully restart Godot and run tools/verify_gdvosk.ps1."
		)
		return 1
	return 0


func _test_model_loads() -> int:
	GdvoskAdapterScript.prewarm()
	if not GdvoskAdapterScript.is_model_loaded():
		push_error("Expected Vosk model to load when gdvosk extension is available")
		return 1
	return 0


func _test_transcribe_does_not_crash() -> int:
	var sample_rate := 48000
	var samples := PackedFloat32Array()
	samples.resize(sample_rate)
	for i in samples.size():
		samples[i] = 0.03 * sin(float(i) * 0.02)

	var parsed: Dictionary = GdvoskAdapterScript.transcribe_samples(samples, sample_rate)
	if parsed.get("words") == null:
		push_error("Expected transcribe_samples to return a words array")
		return 1
	return 0
