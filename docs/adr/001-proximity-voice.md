# ADR 001: Proximity voice

**Status:** Accepted

## Context

Asymmetric horror requires spatial voice: players hear each other based on distance and maze occlusion. Global Steam lobby chat violates the proximity pillar.

Spell STT captures microphone input for incantations via Godot `MicCapture`. Proximity VoIP uses **GodotSteam voice + dedicated P2P channels** so spell validation stays independent for MVP.

## Decision

Use **[godot-steam-voice](https://github.com/iamemilio/godot-steam-voice)** — developed in **`vendor/godot-steam-voice/`** (local clone, gitignored) and packaged into **`addons/godot-steam-voice/`** (tracked; what release exports ship). Current package: see `addons/godot-steam-voice/VERSION.txt` (synced from library `main` / releases such as **v0.1.3**).

Refresh package with `make sync-voice-addon` after library commits. Push library fixes to GitHub first, then sync + commit the addon in Friend Slop so tester release ZIPs include them.

### Product modes (Friend Slop hub)

`SteamProximityVoiceHub` keeps product modes **`OFF` / `LOBBY` / `GAME`**, implemented as two library **`VoiceRuntime`** children:

| Mode | Runtime | Config |
|------|---------|--------|
| `OFF` | both stopped | — |
| `LOBBY` | `LobbyRuntime` | `EPHEMERAL_CLUSTER`, `proximity.enabled = false` (open mic) |
| `GAME` | `GameRuntime` | `MEMBERS`, library game-ready proximity (8 m / 40 m) |

Always call `set_mode(OFF)` / `stop_session()` to tear down (autoload survives scene changes). Runtimes share **one** `VoiceSession` + **one** `VoiceChannel`.

### Library building blocks

- **`VoiceRuntime`** + **`VoiceContextConfig`** / **`ProximitySettings`** — Inspector-configured start/stop
- **`VoiceSession`** — one Steam capture stream; one send/decompress per packet
- **`VoiceChannel`** — presets + composable **`VoiceRule`** stack (single channel by default)
- **`MufflingMap`** for maze wall occlusion
- GodotSteam **`getVoice` / `decompressVoice`**; **`sendP2PPacket` / `readP2PPacket`** on dedicated P2P port
- **`VoiceMember`** on player `Head` nodes for GAME binding

Spell STT in `spell_casting_session.gd` stays independent.

**Not used:** Steam lobby voice during `MatchState.ACTIVE`.

## Deprovisioning

Hub is an autoload — scene unload alone does not stop voice. Lifecycle events must call `set_mode(OFF)` / `stop_session()`:

- Leave lobby / disconnect
- Host start-game RPC (all peers, before loading main)
- Match end / quit to menu
- App Exit / window close (`SteamService` teardown)

Hard crash: best-effort only via Steam client cleanup; no in-game guarantee.

## Consequences

- Lobby: opt-in checkbox; open mic via proximity disabled
- Active maze: proximity falloff (+ optional wall muffling later)
- CI disables voice processing when `FRIEND_SLOP_TEST=1` or `STEAM_PROXIMITY_VOICE_TEST=1`
- Release builds include whatever is committed under `addons/godot-steam-voice/`

## References

- https://github.com/iamemilio/godot-steam-voice (releases / v0.1.3+)
- `addons/godot-steam-voice/INSTALL.txt` / `VERSION.txt`
- `docs/adr/002-steam-p2p-transport.md` — game RPCs on channel 0; voice on addon P2P port
- `tools/sync_godot_steam_voice.py` / `make sync-voice-addon`
