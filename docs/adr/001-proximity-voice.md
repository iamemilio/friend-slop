# ADR 001: Proximity voice

**Status:** Proposed (stub — Phase 1 spike)

## Context

Asymmetric horror requires spatial voice: players hear each other based on distance and maze occlusion. Global lobby voice (e.g. Steam lobby chat) violates the proximity pillar.

Spell STT already captures microphone input for incantations. Proximity VoIP must share capture carefully without entangling routing with spell validation.

## Decision (TBD)

Phase 1 will spike and document one of:

1. **WebRTC over Steam P2P** — custom encoded audio or separate channel; signaling via host RPC.
2. **Godot audio bus simulation (local prototype first)** — fast iteration; networked VoIP added in Phase 1b.
3. **Reject Steam lobby voice for gameplay** — may remain for pre-match lobby only.

**Current recommendation:** Local attenuation prototype (Phase 1a), then networked VoIP with host-mediated signaling (Phase 1b). Do not use Steam built-in lobby voice during `MatchState.ACTIVE`.

## Consequences

- `ProximityVoiceManager` autoload with narrow API (register speaker, set listener, apply occlusion).
- Lobby: full voice until match phase becomes `ACTIVE`.
- Settings: push-to-talk override for streamers.

## References

- `docs/ASYMMETRIC_HORROR_PLAN.md` — Phase 1
- `docs/adr/002-steam-p2p-transport.md` — game packets only on Steam P2P
