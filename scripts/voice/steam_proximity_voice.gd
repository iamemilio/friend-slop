class_name SteamProximityVoice
extends VoiceMember

## Proximity voice anchor — attach as a child of the player Head node.


func _find_voice_session() -> VoiceSession:
	return SteamProximityVoiceHub.get_session()
