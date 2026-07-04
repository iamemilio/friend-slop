class_name TestDeliveryObjectiveAudio
extends RefCounted

const DeliveryObjectiveAudioScript := preload(
	"res://scripts/objectives/delivery_objective_audio.gd"
)


func run() -> int:
	var failures := 0
	failures += _test_ping_range_scales_with_maze()
	failures += _test_ping_range_uses_sixty_percent_coverage()
	return failures


func _test_ping_range_scales_with_maze() -> int:
	var small := DeliveryObjectiveAudioScript.ping_max_distance(15, 15, 3.0)
	var large := DeliveryObjectiveAudioScript.ping_max_distance(30, 30, 3.0)
	if large <= small:
		push_error("Expected larger mazes to increase relic ping audible range")
		return 1
	return 0


func _test_ping_range_uses_sixty_percent_coverage() -> int:
	var span := DeliveryObjectiveAudioScript.maze_world_span(15, 15, 3.0)
	var expected := span * DeliveryObjectiveAudioScript.PING_AUDIBLE_COVERAGE
	var actual := DeliveryObjectiveAudioScript.ping_max_distance(15, 15, 3.0)
	if not is_equal_approx(actual, expected):
		push_error("Expected ping range to cover 60%% of maze span")
		return 1
	if not is_equal_approx(span, 93.0):
		push_error("Expected default 15x15 maze span to be 93 world units")
		return 1
	return 0
