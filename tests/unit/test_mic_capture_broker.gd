class_name TestMicCaptureBroker
extends RefCounted

## Guards MicCaptureBroker API: subscribe lifecycle, inject fan-out, sole drain owner.

const MicCaptureBrokerScript := preload("res://scripts/voice/mic_capture_broker.gd")


func run() -> int:
	var failures := 0
	failures += _test_subscribe_unsubscribe()
	failures += _test_inject_fanout()
	failures += _test_spell_session_uses_listener_sink()
	failures += _test_hub_exposes_listener_api()
	failures += _test_voice_chat_does_not_drain_or_subscribe()
	failures += _test_broker_exposes_ensure_mic_live()
	failures += _test_settings_uses_broker_only()
	return failures


func _test_subscribe_unsubscribe() -> int:
	var broker: Node = MicCaptureBrokerScript.new()
	broker.call("set_fanout_policy", MicCaptureBrokerScript.FanoutPolicy.MATCH_FANOUT)
	var hits := {"n": 0}
	var cb := func(_mono: PackedFloat32Array, _rate: int) -> void:
		hits["n"] = int(hits["n"]) + 1
	if not bool(broker.call("subscribe", MicCaptureBrokerScript.SUB_SPELLCASTING, cb)):
		push_error("Expected subscribe(stt) to succeed under MATCH_FANOUT")
		broker.free()
		return 1
	if not bool(broker.call("has_subscriber", MicCaptureBrokerScript.SUB_SPELLCASTING)):
		push_error("Expected has_subscriber(stt) after subscribe")
		broker.free()
		return 1
	broker.call("inject_pcm", PackedFloat32Array([0.5]), 48000)
	if int(hits["n"]) != 1:
		push_error("Expected inject to fan out to spellcasting subscriber")
		broker.free()
		return 1
	broker.call("unsubscribe", MicCaptureBrokerScript.SUB_SPELLCASTING)
	if bool(broker.call("has_subscriber", MicCaptureBrokerScript.SUB_SPELLCASTING)):
		push_error("Expected unsubscribe to clear spellcasting")
		broker.free()
		return 1
	broker.free()
	return 0


func _test_inject_fanout() -> int:
	var broker: Node = MicCaptureBrokerScript.new()
	broker.call("set_fanout_policy", MicCaptureBrokerScript.FanoutPolicy.MATCH_FANOUT)
	var chat_n := {"n": 0}
	var stt_n := {"n": 0}
	broker.call(
		"subscribe",
		MicCaptureBrokerScript.SUB_CHAT,
		func(_m: PackedFloat32Array, _r: int) -> void:
			chat_n["n"] = int(chat_n["n"]) + 1
	)
	broker.call(
		"subscribe",
		MicCaptureBrokerScript.SUB_SPELLCASTING,
		func(_m: PackedFloat32Array, _r: int) -> void:
			stt_n["n"] = int(stt_n["n"]) + 1
	)
	broker.call("inject_pcm", PackedFloat32Array([0.1, 0.2]), 48000)
	if int(chat_n["n"]) != 1 or int(stt_n["n"]) != 1:
		push_error("inject_pcm must fan out to chat and spellcasting")
		broker.free()
		return 1
	broker.free()
	return 0


func _test_spell_session_uses_listener_sink() -> int:
	var path := "res://scripts/spells/spell_casting_session.gd"
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		push_error("Could not read %s" % path)
		return 1
	if src.find("get_spellcasting_listener") < 0 or src.find("attach_sink") < 0:
		push_error(
			"SpellCastingSession must attach a sink to Match Listeners/Spellcasting"
		)
		return 1
	if src.find("subscribe_spellcasting") >= 0:
		push_error("SpellCastingSession must not subscribe the broker directly")
		return 1
	if src.find("AudioStreamMicrophone") >= 0:
		push_error("SpellCastingSession must not open a second mic — use Listeners/Spellcasting")
		return 1
	return 0


func _test_hub_exposes_listener_api() -> int:
	var path := "res://scripts/voice/steam_proximity_voice_hub.gd"
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		push_error("Could not read %s" % path)
		return 1
	for method_name in ["get_spellcasting_listener", "get_chat_listener", "get_mic_broker"]:
		if src.find("func %s" % method_name) < 0:
			push_error("SteamProximityVoiceHub missing %s()" % method_name)
			return 1
	if src.find("subscribe_spellcasting") >= 0:
		push_error("Hub must not own cast-time broker subscribe anymore")
		return 1
	return 0


func _test_voice_chat_does_not_drain_or_subscribe() -> int:
	var path := "res://scripts/voice/simple_voice_chat.gd"
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		push_error("Could not read %s" % path)
		return 1
	if src.find("get_buffer") >= 0:
		push_error("SimpleVoiceChat must not call get_buffer — MicCaptureBroker owns drain")
		return 1
	if src.find("SUB_CHAT") >= 0:
		push_error("SimpleVoiceChat must not broker-subscribe as SUB_CHAT — VoiceSession owns that")
		return 1
	return 0


func _test_broker_exposes_ensure_mic_live() -> int:
	var path := "res://scripts/voice/mic_capture_broker.gd"
	var src := FileAccess.get_file_as_string(path)
	var missing := ""
	if src.find("func ensure_mic_live") < 0:
		missing = "ensure_mic_live()"
	elif src.find("func rebind_mic_stream") < 0:
		missing = "rebind_mic_stream()"
	elif src.find("func set_output_monitor") < 0:
		missing = "set_output_monitor()"
	if not missing.is_empty():
		push_error("MicCaptureBroker must expose %s" % missing)
		return 1
	return 0


func _test_settings_uses_broker_only() -> int:
	var path := "res://scripts/settings_manager.gd"
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		push_error("Could not read %s" % path)
		return 1
	var err := ""
	if src.find("AudioStreamMicrophone") >= 0:
		err = "SettingsManager must not open its own AudioStreamMicrophone"
	elif src.find("get_buffer") >= 0:
		err = "SettingsManager must not drain AudioEffectCapture — broker owns drain"
	elif src.find("SUB_METER") < 0:
		err = "SettingsManager mic test must subscribe MicCaptureBroker SUB_METER"
	elif src.find("set_output_monitor") < 0:
		err = "SettingsManager must sync hear_myself to MicCaptureBroker output monitor"
	elif src.find("hear_myself") < 0:
		err = "SettingsManager must persist hear_myself"
	if not err.is_empty():
		push_error(err)
		return 1
	return 0
