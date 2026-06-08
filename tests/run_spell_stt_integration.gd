extends SceneTree

## Full STT integration tests (requires gdvosk extension enabled).
## Run: godot --path . --script res://tests/run_spell_stt_integration.gd
## Do not run headless — use the normal editor Godot binary on Windows.

const TestGdvoskRuntime := preload("res://tests/integration/test_gdvosk_runtime.gd")
const TestSpellPipeline := preload("res://tests/unit/test_spell_pipeline.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("Running spell STT integration tests...")
	var failures := 0

	var pipeline_suite := TestSpellPipeline.new()
	failures += pipeline_suite.run(self)

	var runtime_suite := TestGdvoskRuntime.new()
	failures += runtime_suite.run()

	if failures == 0:
		print("Spell STT integration tests passed.")
		_finish(0)
	else:
		push_error("%d spell STT integration test(s) failed." % failures)
		_finish(1)


func _finish(exit_code: int) -> void:
	quit(exit_code)
