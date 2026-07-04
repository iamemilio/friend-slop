# Asymmetric Horror Maze — Implementation Plan

North-star game: **3 survivors + 1 Warden** cooperate (or compete) inside a procedural maze. Survivors activate **ritual anchors** using **co-op puzzles** and **proximity voice**. The Warden manipulates the maze and sows mistrust. **Nobody is eliminated** — downed players become **Sealed** and rejoin via **rescue** or **self-escape**.

This document is the engineering plan: phases, architecture, testing gates, and definitions of done. Design rationale lives in chat history; this file is what we build against.

---

## Non-negotiable pillars

Every feature must pass these checks before merge:

| Pillar | Requirement |
|--------|-------------|
| **Proximity voice** | No global in-game voice. Speech is spatial; walls muffle; sealed rooms leak muffled audio. |
| **Set back, not out** | Downed → Sealed → timer → rescue **or** self-escape → rejoin at checkpoint. No spectator mode. |
| **Team win, personal agency** | Match outcome is shared; individual contributions tracked (rescue, self-escape, anchor, hold). |
| **Soft puzzle failure** | Mistakes cost time / Warden dread, not run-ending resets. |
| **Warden targets teams** | Powers punish splits and coordination loss, not focused bullying of one weak player. |
| **Tested foundation** | New systems ship with unit tests; networked flows with integration tests or documented smoke scripts. |

---

## Current codebase (starting point)

| Keep & extend | Replace or sideline |
|---------------|---------------------|
| `MazeGenerator` / `MazeCarver` | First-to-exit race win (`main.gd` → `exit_reached`) |
| `NetworkManager` + `MultiplayerTransport` + netfox player sync | Symmetric 4-player “everyone is a racer” loop |
| `DiscoverableSpawnPlan` / `Interactable` | Competitive victory scene as default end |
| Voice spell pipeline (STT, validation, effects) | — |
| `GameState.run_seed`, lobby flow | `GameState` copy still says “snail race” |
| `@rpc` / server authority patterns in `NetworkManager` | **Noray + room codes** as primary shipping path → **Steam P2P** |

Existing test harness: `tests/run_tests.gd`, `make test`, CI via `tools/run_godot_tests.sh`. **Extend this pattern** — do not bolt on untested networking logic.

---

## Architecture principles

### 1. Server-authoritative match state

Host (server) owns:

- Role assignment, anchor progress, puzzle state, sealed placements, Warden dread, maze mutations.

Clients send **requests**; server validates and **broadcasts** state deltas. Follow the existing spell RPC pattern in `NetworkManager` (`request_*` → server → `broadcast_*`).

Introduce a dedicated **`MatchState`** (autoload or child of `NetworkManager`) rather than scattering flags across `main.gd`.

### 2. Data-driven content

- **Anchors**, **sealed-room escape templates**, **Warden powers**, **co-op puzzles** → Resources (`.tres`) + small scripts.
- Logic in code; tuning in data. Enables tests with fixture resources.

### 3. Mode flag during transition

`GameState.game_mode: GameMode` enum:

- `LEGACY_RACE` — current behavior until removed.
- `ASYMMETRIC_HORROR` — new loop.

Menu selects mode. Allows incremental merge without breaking existing playtests.

### 4. Proximity voice is its own subsystem

Do not entangle VoIP with spell STT internals. Shared **microphone capture** is fine; **routing** (who hears whom) is a separate module with a narrow API.

**Steam carries game packets only** — not Steam lobby voice chat. Proximity speech stays custom (see ADR 001).

### 5. Transport behind `MultiplayerTransport`

`NetworkManager` never calls Noray or Steam directly. Implement **`SteamTransport`** as the shipping backend; keep **`NorayTransport`** as temporary dev fallback. CI uses **`FakeTransport` / offline** — no Steam API in headless tests.

See **`docs/adr/002-steam-p2p-transport.md`**.

---

## Target architecture (high level)

```
┌─────────────────────────────────────────────────────────────┐
│  Menu / Lobby                                               │
│  - role pick (Survivor / Warden)                            │
│  - proximity voice: FULL (pre-game only)                    │
└──────────────────────────┬──────────────────────────────────┘
                           │ start_game(run_seed, roles)
┌──────────────────────────▼──────────────────────────────────┐
│  MatchState (server authority, synced snapshot)              │
│  - phase, anchor_progress, checkpoints                       │
│  - sealed_players{}, warden_dread                            │
│  - puzzle_states{}, maze_mutations{}                         │
└─────┬───────────────┬────────────────┬──────────────────────┘
      │               │                │
      ▼               ▼                ▼
 Survivor scene   Warden UI      ProximityVoiceManager
 (player.tscn)   (map + powers)  (spatial audio graph)
      │               │                │
      └───────────────┴────────────────┘
                      │
              MazeGenerator (+ mutation hooks)
              Interactable / Anchor / SealedRoom
              SpellCastingSession (proximity-gated)
```

---

## Testing strategy

### Unit tests (`tests/unit/`)

Pure logic, no scene tree or headless Godot where possible:

- Role assignment, match phase transitions.
- Sealed placement fairness rules (grid distance, region constraints).
- Dread economy (gain/spend/caps).
- Anchor progress, checkpoint save/load.
- Puzzle state machines (dual lever, sealed escape).
- Proximity voice **attenuation/occlusion** math (room graph).

Naming: `test_match_state.gd`, `test_sealed_placement.gd`, `test_warden_dread.gd`, etc.

### Integration tests (`tests/integration/`)

Headless Godot scenes:

- Sealed lifecycle: downed → sealed → timer → rescue/escape → rejoin.
- Anchor activation with mocked peers (use existing multiplayer test patterns from `test_network_manager.gd`).
- Co-op puzzle: two player stubs must hold within time window.

### Multiplayer smoke (manual + script)

- `tools/smoke/` or extend `make test-ci` later: document **2-client** and **4-client** checklists.
- Phase 0 gate: host + 1 join, roles assigned, both load main scene.

### Definition of done (every PR)

- [ ] Unit tests for new pure logic.
- [ ] No new `@warning_ignore` without comment.
- [ ] `make lint` + `make test` pass.
- [ ] If networked: server authority documented in class docstring.
- [ ] If designer-tunable: `.tres` or exported vars with sane defaults.

---

## Phase 0A — Steam P2P transport (shipping network stack)

**Goal:** Replace Noray room codes with Steam lobbies + P2P for real playtests and release. No change to netfox sync or RPC semantics.

**Prerequisite for:** friend invites, Steam Deck distribution, stable NAT without Noray relay.

### Deliverables

1. **GodotSteam setup**
   - Add GodotSteam GDExtension (4.17+ / Godot 4.6.x matched build).
   - `steam_appid.txt` in repo root (480 for dev; production ID via env/export).
   - `SteamService` autoload: `steamInitEx`, run callbacks each frame, graceful offline if Steam missing.

2. **`SteamTransport` extends `MultiplayerTransport`**
   - `host(options)` → `createLobby` → on success `SteamMultiplayerPeer.host_with_lobby`.
   - `join(options)` → `joinLobby(lobby_id)` → `create_client(lobby_owner_steam_id)`.
   - `allowP2PPacketRelay(true)` on host and client.
   - `MAX_PLAYERS := 4` (same as Noray).
   - Guard: on `lobby_joined`, skip `create_client` if local user is lobby owner (host path only).

3. **`NetworkManager` transport selection**
   - `NetworkBackend` enum or project setting: `STEAM` (default in export), `NORAY` (dev), `OFFLINE` (solo test).
   - Inject transport in `_ready` or from `project.godot` feature tag.

4. **Lobby UI (`lobby_panel.gd`)**
   - Remove Noray host field from default UI (dev toggle ok).
   - Host: show lobby ID + **Invite Friends** (`Steam.activateGameOverlayInviteDialog`).
   - Join: paste lobby ID **or** accept Steam invite callback → auto-join.
   - Roster: Steam display names + existing role labels (Phase 0).

5. **Peer identity helpers**
   - Optional: map `peer_id` ↔ `steam_id` for logging and ban list later (`SteamMultiplayerPeer.get_steam_id_for_peer_id`).
   - Do **not** rewrite game logic to use Steam IDs where peer ids work today.

6. **Deprecate Noray path**
   - Document removal milestone in Phase 7.
   - netfox.noray addon unused in shipping builds (may remain in tree until cleanup PR).

### Key files

| Action | Path |
|--------|------|
| Create | `scripts/network/steam_service.gd`, `scripts/network/steam_transport.gd` |
| Extend | `scripts/network/network_manager.gd`, `scripts/ui/lobby_panel.gd` |
| Create | `docs/adr/002-steam-p2p-transport.md` (decision record) |
| Extend | `export_presets.cfg` — bundle GodotSteam libs per platform |

### Tests

- `tests/unit/test_steam_transport.gd` — mock `SteamService`; lobby owner guard, join validation, disconnect cleanup.
- Existing `test_network_manager.gd` fake transport tests unchanged.
- **Manual smoke:** two Steam clients, host invite, load main scene, move both snails.
- CI: `make test` does **not** load GodotSteam (use `STEAM_DISABLED` or absence of GDExtension in headless).

### Exit criteria

- Two Steam accounts connect via lobby invite; RPC spell + movement sync work as today.
- Game runs without Steam only when explicitly in offline/solo mode (clear error in lobby otherwise).
- ADR 002 accepted; Noray hidden from default menu.

---

## Phase 0 — Foundation & match model

**Goal:** Shared vocabulary and synced state skeleton. No new gameplay yet.

**Depends on:** Phase 0A recommended before multiplayer playtests; unit tests may use fake transport without Steam.

### Deliverables

1. **`GameMode` enum** on `GameState` + `prepare_asymmetric_match(seed, roles)`.
2. **`PlayerRole` enum:** `SURVIVOR`, `WARDEN`.
3. **`MatchState` resource + manager**
   - Phases: `LOBBY`, `BRIEFING`, `ACTIVE`, `RESOLVING`, `ENDED`.
   - Fields: `anchor_count`, `anchors_activated`, `checkpoint_anchor_id`, `sealed_peers: Dictionary`.
4. **Lobby role selection** in `lobby_panel.gd`
   - Exactly one Warden before start; 2–3 Survivors (support 3+1 for `MAX_PLAYERS=4`).
   - Host cannot start without valid roster.
5. **Network sync:** `MatchStateSnapshot` (packed dict or custom codec) broadcast on change; clients apply read-only view.

### Key files

| Action | Path |
|--------|------|
| Extend | `scripts/game_state.gd` |
| Create | `scripts/match/match_state.gd`, `scripts/match/match_state_sync.gd` |
| Extend | `scripts/network/network_manager.gd`, `scripts/ui/lobby_panel.gd` |
| Create | `resources/match/default_horror_config.tres` |

### Tests

- `tests/unit/test_match_state.gd` — phase transitions, invalid transitions rejected.
- `tests/unit/test_role_assignment.gd` — one warden, peer count edges.
- Extend `tests/unit/test_network_manager.gd` — start game passes roles.

### Exit criteria

- Host starts asymmetric lobby → all clients receive roles + shared seed.
- `MatchState` visible in debug HUD or log.
- Legacy race still launchable via `LEGACY_RACE`.

---

## Phase 1 — Proximity voice (vertical slice)

**Goal:** Prove the core social experience before heavy gameplay. Two players in maze; voice fades with distance; walls muffle.

### Technical spike (ADR required)

**Done** — see `docs/adr/001-proximity-voice.md` and packaged addon at `addons/godot-steam-voice/`. Game wiring: `FriendSlopVoiceAdapter` autoload; maze muffling via `MufflingMap`; spatial rules enabled on `MatchState.ACTIVE`.

<details>
<summary>Original spike notes (historical)</summary>

Document choice in `docs/adr/001-proximity-voice.md`:

| Option | Pros | Cons |
|--------|------|------|
| **WebRTC over Steam P2P** (custom packets / separate channel) | Reuses Phase 0A NAT; full spatial control | Custom protocol work |
| **Steam lobby voice** | Easy | **Global chat — violates proximity pillar** |
| **Godot 4 audio bus simulation (local only first)** | Fast prototype | Not true VoIP until networked |

**Recommendation:** Phase 1a local attenuation prototype → Phase 1b networked VoIP (WebRTC or encoded audio over game peer) with **signaling via host RPC**. Do not use Steam’s built-in lobby voice for gameplay.

</details>

### Deliverables

1. **`FriendSlopVoiceAdapter`** (replaces planned `ProximityVoiceManager`) — wires `VoiceSession` to player heads and maze muffling.
2. **Occlusion model v1:** maze grid **room id** per cell (from `MazeCarver`); same room = clear; adjacent = −12 dB; 2+ walls = −24 dB; sealed chamber = leak profile.
3. **Lobby vs match:** full voice in lobby; on `MatchState.ACTIVE`, enforce proximity rules.
4. **Settings:** push-to-talk override (streamer mode); emote wheel (short-range presets) — optional stub UI.

### Integration with spells

- Spell STT continues on mic capture bus.
- VoIP taps same capture **after** AEC consideration (document limitation in MVP).
- Incantations audible to nearby players via proximity routing.

### Tests

- `tests/unit/test_proximity_attenuation.gd` — distance → gain.
- `tests/unit/test_voice_occlusion.gd` — room graph cases.
- Manual: 2 instances, walk apart until silent.

### Exit criteria

- Two clients hear each other only when close.
- Walking through wall muffles speech noticeably.
- Documented known issues (echo, NAT) acceptable for MVP.

---

## Phase 2 — Objectives: anchors & checkpoints

**Goal:** Replace race-to-exit with co-op win condition and progress persistence.

### Deliverables

1. **`AnchorDefinition` resource** — id, display name, world hint, activation requirements.
2. **`AnchorInteractable`** — extends `Interactable`; server validates activation; increments `MatchState.anchors_activated`.
3. **Win condition:** all anchors active → `MatchState.phase = RESOLVING` → survivor win (Warden loss).
4. **Lose condition (v1):** time limit **or** Warden dread threshold (pick one for MVP; tune later).
5. **Checkpoints:** on anchor activation, save `checkpoint_anchor_id`; sealed rejoin spawns near checkpoint region.
6. **Spawn plan:** extend `DiscoverableSpawnPlan` or parallel `AnchorSpawnPlan` with min-distance rules.

### Key files

| Action | Path |
|--------|------|
| Create | `scripts/objectives/anchor_definition.gd`, `anchor_interactable.gd`, `anchor_spawn_plan.gd` |
| Extend | `scripts/main.gd` — remove sole reliance on `exit_reached` in horror mode |
| Create | `resources/objectives/horror_run_config.tres` |

### Tests

- `tests/unit/test_anchor_spawn_plan.gd`
- `tests/unit/test_match_win_conditions.gd`
- Integration: single-player activate 3 anchors → win phase.

### Exit criteria

- Horror mode match ends on anchor completion, not crystal touch.
- Checkpoint survives sealed cycle (Phase 3).

---

## Phase 3 — Sealed state (downed → rescue / self-escape)

**Goal:** Implement the setback loop with fairness and proximity-driven rescue.

### State machine (per player)

```
ACTIVE → DOWNED (brief) → SEALED_WAIT (timer) → SEALED_ACTIVE → ACTIVE
                              │                      │
                              │                      ├─ rescued (teammate)
                              │                      └─ self_escape (puzzle)
```

### Deliverables

1. **`SealedController`** (server) — triggers on downed event; picks cell via **`SealedPlacementPolicy`**:
   - Min graph distance from living survivors (config: 8–15 cells).
   - Not in Warden-blocked zone / final anchor room.
   - First seal per player: softer (closer, shorter timer).
2. **`SealedRoom` scene** — enclosed cell + door marker + leak audio emitter.
3. **Timer:** `SEALED_WAIT` 30–45s; player can speak (leaks); emote whispers slightly farther.
4. **Self-escape v1:** one template — voice incantation OR hold channel (data-driven via `SealedEscapeDefinition`).
5. **Rescue v1:** teammate at door, hold 4s; dual-hold optional bonus (faster).
6. **Rejoin:** teleport to checkpoint region; brief invuln or Warden stun (0.5s dread pause).
7. **Proximity:** muffled voice through door; volume rises as rescuer approaches (tie to Phase 1).

### Key files

| Action | Path |
|--------|------|
| Create | `scripts/sealed/sealed_controller.gd`, `sealed_placement_policy.gd`, `sealed_room.gd`, `sealed_escape_definition.gd` |
| Create | `scenes/sealed/sealed_room.tscn` |
| Extend | `scripts/player.gd` — downed trigger hook |

### Tests

- `tests/unit/test_sealed_placement_policy.gd` — fairness constraints, regression fixtures with fixed seeds.
- `tests/unit/test_sealed_state_machine.gd` — timer, transitions, double-seal escalation.
- Integration: `tests/integration/test_sealed_lifecycle.gd`

### Exit criteria

- Player can be sealed, wait, escape solo or be rescued, rejoin with checkpoint.
- Sealed player never loses camera control or match participation.
- Muffled voice heard near door in manual 2-client test.

---

## Phase 4 — Co-op puzzles (framework + one puzzle)

**Goal:** Reusable synced puzzle module; ship dual-lever as reference implementation.

### Deliverables

1. **`CoopPuzzle` base** — `puzzle_id`, required peers, state enum, server authority, `sync_state()` RPC.
2. **`DualLeverPuzzle`** — two switches, must overlap hold window (3s); stall on failure, no hard reset.
3. **Proximity gate:** puzzle only advances if required players within `coordination_radius` (ties to voice design).
4. **Link to anchors:** anchor 2 requires dual-lever completion nearby.

### Tests

- `tests/unit/test_dual_lever_puzzle.gd` — timing windows, partial hold.
- Integration with two peer stubs.

### Exit criteria

- Puzzle state survives reconnect (host stores state).
- Failure increments Warden dread slightly (hook for Phase 5).

---

## Phase 5 — Warden client (dread + three powers)

> **Updated direction:** See [`WARDEN_TRICKSTER_PLAN.md`](WARDEN_TRICKSTER_PLAN.md) for the trickster-director Warden, Chime acts, fling/cut/false-wall mechanics, and dual win (time tax + Spectacle). The deliverables below remain a useful baseline; implementation should follow the trickster plan.

**Goal:** Asymmetric antagonist with readable UI and bounded power.

### Deliverables

1. **`WardenView`** scene — abstract maze map, delayed survivor blips (2s), dread meter.
2. **`WardenDread` economy** — gain on team split, puzzle stall, failed lever; spend on powers; cap + regen rules.
3. **Powers MVP:**

   | Power | Cost | Effect |
   |-------|------|--------|
   | **Seal corridor** | medium | Temp wall on edge (60s) |
   | **Fog pulse** | low | Global survivor visibility debuff 10s |
   | **Whisper** | medium | Fake ping or muffled false line to one survivor |

4. **`MazeMutationService`** — server validates graph edits; `MazeGenerator` exposes edge seal/unseal API.
5. **Anti-bully:** immunity after 2 seals in 120s; Warden cannot seal same player’s room twice in a row.

### Key files

| Action | Path |
|--------|------|
| Create | `scripts/warden/warden_dread.gd`, `warden_powers.gd`, `maze_mutation_service.gd` |
| Create | `scenes/warden/warden_view.tscn`, `scripts/warden/warden_view.gd` |
| Extend | `scripts/maze_generator.gd` / carver — mutation hooks |

### Tests

- `tests/unit/test_warden_dread.gd`
- `tests/unit/test_maze_mutation_service.gd` — invalid edge rejected
- `tests/unit/test_warden_targeting_limits.gd`

### Exit criteria

- Warden player has distinct client UI; survivors never see map god view.
- Three powers work in 4-client manual session.
- Dread cannot spam infinite seals.

---

## Phase 6 — Bindings, personal goals & proximity spells

**Goal:** Approachability layer and signature voice co-op.

### Deliverables

1. **Bindings (light):** `Lantern`, `Scribe`, `Pathfinder` — lobby pick or auto-suggest for first-time players.
   - Lantern: +10% ally proximity voice range (still not global).
   - Scribe: teaches tomes faster when nearby ally listens.
   - Pathfinder: map ping cooldown (visual only, not voice).
2. **Personal objectives** — tracked in `MatchState`; end screen shows team + personal lines.
3. **Proximity-gated harmonics puzzle** — two incantations within 3s if both within 5m.
4. **Spell teaching** — learning tome requires ally within range to “witness” (optional co-op unlock).

### Tests

- Unit tests for binding modifiers (numeric).
- Integration: harmonics puzzle with distance check.

### Exit criteria

- End screen reflects personal + team outcome.
- New-player Lantern path viable in playtest.

---

## Phase 7 — Polish, deprecate legacy, ship vertical slice

**Goal:** One shippable asymmetric mode; legacy race optional or removed.

### Deliverables

1. Menu copy + mode select (`Asymmetric Horror` default).
2. Briefing cards (survivor vs warden goals).
3. Match length target 15–20 min (time limit + anchor count tuning).
4. Remove or hide `LEGACY_RACE` behind dev flag.
5. **`docs/PLAYTEST.md`** — session script, balance knobs, known issues.
6. CI unchanged; add note if integration tests need `GODOT_TEST_TIMEOUT_SEC` bump.

### Exit criteria

- Full 3+1 session playable start → finish.
- `make test` green; playtest checklist signed off once.

---

## Suggested build order (timeline-agnostic)

```
Phase 0A (Steam P2P) ──► Phase 0 (match model)
         │                      │
         └──────────┬───────────┘
                    ▼
         Phase 1 (proximity voice) ──► Phase 2 (anchors)
                    │                    │
                    └──────────┬─────────┘
                               ▼
                         Phase 3 (sealed)
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
              Phase 4 (puzzles)     Phase 5 (warden)
                    │                     │
                    └──────────┬──────────┘
                               ▼
                         Phase 6 (bindings)
                               │
                               ▼
                         Phase 7 (ship slice + drop Noray)
```

**Parallelizable:** Phase 0 match-state **unit tests** alongside Phase 0A; multiplayer playtests wait for Steam. Phase 4 and 5 after Phase 3 — agree on `MatchState` API first.

---

## Risk register

| Risk | Mitigation |
|------|------------|
| GodotSteam / export template mismatch | Pin GodotSteam version in `tools/versions.env`; document editor vs export binary |
| Steam not running in dev | Clear lobby error; optional Noray dev fallback until Phase 7 |
| Host double-connect on lobby create | `getLobbyOwner` guard (see ADR 002) |
| Proximity VoIP NAT failures | Signaling over existing Steam P2P host; fallback emote wheel |
| Mic + VoIP echo | Push-to-talk streamer mode; document headset requirement |
| Maze mutation desync | Server-only graph; clients receive delta list; unit test mutations |
| Sealed player griefing (Warden camps body) | Rescue leak audio from distance; self-escape always valid; targeting limits |
| Scope creep on puzzles | One reference puzzle per phase; data-driven templates after |
| gdvosk headless crashes | Keep existing test disable pattern; sealed voice puzzles use same STT path with integration test |

---

## Config tuning (single resource)

Create `resources/match/horror_tuning.tres` (or `horror_tuning.gd` constants) for:

- `sealed_wait_seconds`, `sealed_min_distance_cells`, `coordination_radius`
- `proximity_full_volume_m`, `proximity_silent_m`
- `warden_dread_*` gains/costs
- `anchor_count`, `match_time_limit_seconds`

Playtests adjust one file; tests lock defaults.

---

## Immediate next steps

**Phase 0A (Steam) — do first if targeting Steam playtests:**

1. Accept ADR 002; register / confirm Steam App ID (480 for dev).
2. Integrate GodotSteam GDExtension; `SteamService` autoload + callback pump.
3. Implement `SteamTransport` + unit tests with mocked Steam API.
4. Update lobby UI: invite flow, drop Noray from default path.
5. Manual smoke: 2 Steam clients, host + join, verify movement RPC.

**Phase 0 (match model) — parallel where possible:**

1. Create `docs/adr/001-proximity-voice.md` stub.
2. Implement `MatchState` + `GameMode` with unit tests.
3. Add role fields to lobby + `NetworkManager.start_game` payload.
4. Debug overlay showing role + match phase in horror mode.

---

## Glossary

| Term | Meaning |
|------|---------|
| **Survivor** | Apprentice in the maze; activates anchors. |
| **Warden** | Asymmetric player; maze powers + dread. |
| **Anchor** | Ritual objective; progress + checkpoint. |
| **Sealed** | Downed state; random chamber; wait → rescue or escape. |
| **Binding** | Lightweight role modifier (Lantern / Scribe / Pathfinder). |
| **Dread** | Warden resource for powers. |

---

*Last updated: 2026-06-08 — asymmetric horror, sealed/rescue, proximity voice, approachability, **Steam P2P transport (Phase 0A)**.*
