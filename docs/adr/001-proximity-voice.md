# ADR 001: Proximity voice

**Status:** Accepted

## Context

Asymmetric horror requires spatial voice: players hear each other based on distance and maze occlusion. Global lobby voice (e.g. Steam lobby chat) violates the proximity pillar.

Spell STT captures microphone input for incantations via Godot `MicCapture`. Proximity VoIP uses **GodotSteam voice + dedicated P2P channels** so spell validation stays independent for MVP.

## Decision

Use **[godot-steam-voice](https://github.com/iamemilio/godot-steam-voice)** — packaged into **`addons/godot-steam-voice/`**:

- **`VoiceSession`** root node; one send/decompress per packet
- **`VoiceChannel`** with presets (`PROXIMITY`, `GLOBAL`, `CUSTOM`) and composable **`VoiceRule`** stack
- **`MufflingMap`** for maze wall occlusion (built from `MazeGenerator` wall grid)
- GodotSteam **`getVoice` / `decompressVoice`** for codec; **`sendP2PPacket` / `readP2PPacket`** on dedicated P2P port
- Register listener/speaker **`Node3D`** on player `Head` nodes

Friend Slop integrates via thin **`FriendSlopVoiceAdapter`** autoload. Spell STT in `spell_casting_session.gd` unchanged until unified mic is proven.

Source library lives at **`vendor/godot-steam-voice/`** (git clone). Refresh packaged addon with `make sync-voice-addon`.

**Not used:** Steam lobby voice during `MatchState.ACTIVE`; custom PCM-over-RPC spike.

## Consequences

- Briefing: `ProximityVolume` and `WallMuffling` rules disabled → full-volume voice
- Active maze: proximity falloff + wall muffling enabled
- Walkie/radio effects available via channel preset flags when needed
- CI disables voice processing when `FRIEND_SLOP_TEST=1` or `STEAM_PROXIMITY_VOICE_TEST=1`

## References

- https://github.com/iamemilio/godot-steam-voice
- `addons/godot-steam-voice/INSTALL.txt`
- `docs/adr/002-steam-p2p-transport.md` — game RPCs on channel 0; voice on addon P2P port
