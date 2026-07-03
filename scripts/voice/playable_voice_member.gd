class_name PlayableVoiceMember
extends VoiceMember

## Routes voice registration to FriendSlopVoiceAdapter's session (autoload, not a scene ancestor).


func _find_voice_session() -> VoiceSession:
	return FriendSlopVoiceAdapter.get_voice_session()
