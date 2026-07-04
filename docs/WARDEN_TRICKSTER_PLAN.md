# Warden Trickster & Chime Acts — Implementation Plan

Companion to [`ASYMMETRIC_HORROR_PLAN.md`](ASYMMETRIC_HORROR_PLAN.md). This document replaces the **punish-first** framing of Phase 5 with a **director / trickster** Warden and ships the first **3D comedy mechanics** + **Chime** recurring objective.

North star: **Apprentices play co-op escape; the Warden plays petty maze deity.** Both sides can win. Time tax is fine. Seals and pressure exist, but **pranks and spectacle** are the main Warden fantasy.

---

## Non-negotiable pillars

| Pillar | Requirement |
|--------|-------------|
| **Dual win** | Apprentices can finish the ritual; Warden can win on **time tax** and/or **Spectacle** even when apprentices eventually succeed. |
| **3D comedy** | Mechanics exploit **sightlines, height, and proximity voice** (flings watched live, screams heard nearby). |
| **Predictable slapstick** | Fling trajectories and landing pads are **fixed and authored** — funny, not random death. |
| **Readable tells** | False walls and maze cuts have **audio + at least one visual/social tell**. |
| **Anti-bully** | Diminishing returns on sealing the same player; Warden rewarded for **variety** and **multi-player bits**. |
| **Server authority** | Maze edits, chime state, fling launches, and scores live on host / `MatchState`. |
| **Tested** | Grid mutation, chime state machine, and spectacle counters get unit tests. |

---

## Win conditions (asymmetric)

### Apprentices (team)

- **Primary:** Complete ritual progress (anchors + **Chime deliveries** per act).
- **Secondary:** Finish with time remaining on the match clock; low seal count; successful rescues.

### Warden (individual)

- **Primary:** **Time tax** — apprentices fail to meet act/match deadline (clock hits zero or ritual incomplete).
- **Secondary:** **Spectacle score** — tagged comedy moments (flings witnessed, false walls fooled, chime stolen, cuts during channel, etc.).

End screen shows **both** team outcome and Warden **Director's Cut** (Spectacle + highlight reel stats). Rematch incentive even when apprentices “win” the run.

---

## Core loop: Acts + Chime

Matches are **2–3 acts**. Each act centers on one **Chime run**.

```
Act start → Chime spawns (periodic ping)
         → Pickup (any role; Warden can steal)
         → Hold to reveal delivery site (holder only)
         → Deliver at site (channel) OR Warden stalls until act timer
         → Brief intermission (full proximity voice OK in safe hub — optional)
         → Next act (more Warden tools unlocked)
```

| Act | Apprentice focus | Warden tools (suggested) |
|-----|------------------|---------------------------|
| **1** | Learn Chime + one delivery | False wall, cheap Whisper |
| **2** | Second delivery + coordination | Cut / open door, one fling trap |
| **3** | Final delivery under time pressure | Full kit + chase |

Tuning target: **15–20 min** total match (see parent plan).

---

## Mechanic specs

### 1. Fling traps

**Fantasy:** Player launched on a **fixed arc**; friends watch and hear them scream via proximity voice.

| Rule | Detail |
|------|--------|
| Trajectory | Authored per trap: `{ trap_id, from_cell, to_cell, arc_curve }`. Same every activation. |
| Air control | **Zero** (or effectively zero). Velocity set at launch. |
| Landing | Always a **designated pad cell** — soft landing, brief stun (0.5–1s), no damage. |
| Telegraph | Floor plate glow + SFX ~1s before arm; optional Warden “arm trap” spell. |
| Spectacle | +score if ≥2 apprentices have line-of-sight to arc (server ray/zone check). |

**Data:** `FlingTrapDefinition` resource + scene trigger volume.  
**Grid:** Trigger on passage cell; landing on target passage cell; validate both walkable.

---

### 2. Cut / open doors (`warden_shift`, `warden_forge`)

**Fantasy:** Warden opens or closes **single-cell passages** through maze walls for chase and stall.

| Spell | Grid effect | Duration |
|-------|-------------|----------|
| **Cut** (close) | Set passage edge to **wall** (block 1-wide door) | 20–40s, then auto-revert |
| **Open** (forge/shift) | Set **valid wall** between two passages to **open** | 20–40s, then auto-revert |
| **Twist** (later) | Rotate small wing connections (existing mutation idea) | One per act |

| Rule | Detail |
|------|--------|
| Validation | Only edges in `MazeCarver` **loop candidate** set (same rules as braid walls). |
| Tell | Loud stone-grind SFX heard within N cells. |
| Fairness | Never the **only** route to Chime delivery or sealed exit without alternate path. |
| Warden UI | God-view map highlights **eligible edges**; apprentices learn audio tell. |

**Implementation:** `MazeMutationService` mutates logical `_wall_grid`; `MazeGenerator` patches collision mesh locally (no full regen every cast).

---

### 3. False walls

**Fantasy:** Temporary fake wall segment; apprentices sus out via tells.

| Tell | Detail |
|------|--------|
| Cast audio | Warden incantation + shimmer SFX (proximity audible). |
| Footprints | Warden trail stops at wall OR shows “through-wall” decal variant. |
| Visual | Subtle material wrongness; **Show Me** highlights shimmer. |
| Touch | Interact “punch wall” → hollow thunk, illusion breaks. |

| Rule | Detail |
|------|--------|
| TTL | 30–45s max. |
| Cap | Max **N** active false walls (e.g. 3). |
| Fail forward | If nobody fooled before break, small Mischief refund (failed bit). |

**Data:** `FalseWallDefinition` + scene; server spawns oriented slab on valid wall cell.

---

### 4. Chime object (recurring mini-game)

**Fantasy:** Periodic **ping** prop; hold to reveal delivery site; Warden can steal and stall.

| State | Behavior |
|-------|----------|
| **Idle (world)** | Ping every 3–4s, spatial audio attenuation. |
| **Carried** | Ping from carrier position; Warden runs slower with Chime. |
| **Hold reveal** | ~2s hold → delivery site marker for **holder** (and faint hint for allies). |
| **Deliver** | Channel at site (3–5s); completes act objective. |

| Rule | Detail |
|------|--------|
| Drop on seal | Chime drops to ground if carrier sealed. |
| Warden steal | Valid pickup; loud ping escalates if held too long (everyone hunts). |
| Delivery site | Picked from reachable cells at act start; not behind permanent dead-end. |

**Data:** `ChimeActDefinition` — ping interval, hold time, channel time, act index.

---

## Economy: Mischief & Spectacle

Rename in **UI copy** only initially (`warden_dread` → “Mischief”); keep field name until refactor.

### Mischief (spend)

| Action | Cost tier |
|--------|-----------|
| False wall | Low |
| Whisper / Mirror | Low–medium |
| Cut / open | Medium |
| Arm fling trap | Medium |
| Seal | High (rare per act) |

### Mischief (earn)

- Apprentices split up during Chime run
- Puzzle stall / failed coordination
- Act timer elapses without delivery (Warden-side)
- **Variety bonus:** first use of each power type per act

### Spectacle (score — Warden secondary win)

Server increments on tagged events:

| Event | Notes |
|-------|--------|
| `fling_witnessed` | ≥2 apprentices in sight cone |
| `false_wall_fooled` | Walk attempt or wasted Show Me on fake |
| `chime_stolen_sec` | Warden held Chime |
| `cut_during_channel` | Door closed during deliver/hold |
| `scream_spike` | Optional: voice RMS threshold after fling |

Store in `MatchState.spectacle_events` or tallies dictionary.

---

## Architecture

```
MatchState (extend)
  - phase, act_index, match_time_remaining
  - chime_state { holder_peer, phase, delivery_cell, act_deliveries }
  - maze_mutations[] { edge, type, expires_at }
  - false_walls[] { cell, normal, expires_at }
  - fling_traps[] { trap_id, armed_until }
  - warden_dread (Mischief)
  - spectacle_score + spectacle_tallies{}
  - apprentice_time_bank (optional bonus from deliveries)

MazeMutationService (server)
  - validate_edge_mutation(grid, edge, type)
  - apply / revert mutation
  - sync snapshot to clients

WardenPowerController (server validates, client predicts VFX)
  - cut, open, false_wall, arm_fling, steal interactions

ChimeController (server)
  - spawn, pickup, drop, hold_reveal, deliver channel

SpectacleTracker (server)
  - increment on events; RPC summary at act end

MazeGenerator (extend)
  - get_wall_grid() ✓ exists
  - apply_patch(cells) → update StaticBody trimesh region
  - world_to_cell / cell_to_world ✓ exists
```

### Key files (planned)

| Action | Path |
|--------|------|
| Create | `docs/WARDEN_TRICKSTER_PLAN.md` (this file) |
| Create | `scripts/match/chime_controller.gd` |
| Create | `scripts/match/spectacle_tracker.gd` |
| Create | `scripts/warden/maze_mutation_service.gd` |
| Create | `scripts/warden/warden_power_controller.gd` |
| Create | `scripts/warden/fling_trap.gd` |
| Create | `scripts/warden/false_wall.gd` |
| Create | `resources/acts/chime_act_*.tres`, `resources/traps/fling_*.tres` |
| Extend | `scripts/match/match_state.gd` — act + chime + spectacle fields |
| Extend | `scripts/maze_generator.gd` — mutation patches |
| Extend | `scripts/progression/spell_display_names.gd` — trickster copy |
| Create | `scenes/warden/warden_view.tscn` (from parent Phase 5) |

---

## Phases (build order)

### Phase T1 — Match act shell + Chime v1

**Goal:** Playable Chime loop without Warden powers.

**Deliverables**

1. Extend `MatchState` with `act_index`, `chime_state`, act timer.
2. `ChimeController` — spawn, pickup, drop, hold-reveal site, deliver channel.
3. Spatial ping audio (carried + world).
4. Act transition when delivery completes or act timer expires.
5. Basic HUD: holder indicator, delivery progress, act clock.

**Tests**

- `tests/unit/test_chime_state_machine.gd`
- `tests/unit/test_match_state_chime_snapshot.gd`

**Exit criteria**

- 4-player session: apprentice can pick up Chime, reveal site, deliver; act advances.
- Warden can pick up and run with Chime (no powers yet).

---

### Phase T2 — Maze mutation (cut / open)

**Goal:** Warden chase tool on grid; timed revert.

**Deliverables**

1. `MazeMutationService` — validate + apply edge open/close on `_wall_grid`.
2. `MazeGenerator.apply_wall_patch()` — collision mesh update.
3. Wire `warden_shift` / `warden_forge` spell requests → server mutation.
4. Audio tell + UI eligible-edge highlights on Warden map.
5. Mischief cost + auto-revert timer.

**Tests**

- `tests/unit/test_maze_mutation_service.gd` — invalid edge rejected, revert restores grid
- Regression: reachable path from spawn to delivery after mutation

**Exit criteria**

- Warden closes door during Chime chase; reopens after TTL.
- Apprentices never soft-locked without alternate route (validation test).

---

### Phase T3 — Fling trap v1

**Goal:** One authored slapstick set piece.

**Deliverables**

1. `FlingTrapDefinition` + scene (trigger + arc).
2. Server launch: zero air control, fixed landing pad.
3. One **sightline-friendly** placement in test maze (atrium or long corridor).
4. Warden “arm trap” or always-on fixture for MVP.
5. `SpectacleTracker` increment on witnessed fling.

**Tests**

- `tests/unit/test_fling_trap_validation.gd` — from/to cells walkable, arc ends on pad

**Exit criteria**

- Manual: 2 apprentices watch 1 fly; scream audible via proximity voice.
- Landing never OOB or inside wall.

---

### Phase T4 — False wall v1

**Goal:** Deception with tells + counterplay.

**Deliverables**

1. `FalseWall` scene — blocks movement until broken or TTL.
2. Warden cast: audio tell + footprint rule.
3. Apprentice interact: punch to dispel.
4. Show Me interaction (optional if spell ready).
5. Cap active walls; Mischief cost.

**Tests**

- `tests/unit/test_false_wall_placement.gd` — only on valid wall cells

**Exit criteria**

- Manual: at least one apprentice fooled; others can sus and punch wall.

---

### Phase T5 — Dual win + Director's Cut

**Goal:** Asymmetric scoring and end screen.

**Deliverables**

1. Match clock + time tax win for Warden.
2. Spectacle tally → `spectacle_score`.
3. End screen: team result + Warden highlights (flings, steals, fools).
4. Act 2–3 unlock table (powers per act).
5. Anti-bully: seal diminishing returns; variety bonus for Mischief.

**Tests**

- `tests/unit/test_spectacle_tracker.gd`
- `tests/unit/test_dual_win_resolution.gd`

**Exit criteria**

- Run can end with apprentice ritual win + Warden Spectacle win displayed.
- Warden can win on time alone.

---

### Phase T6 — Polish & content pass

**Goal:** One shippable vertical slice.

**Deliverables**

1. 2–3 fling trap placements per maze seed class.
2. Briefing cards (apprentice vs Warden goals).
3. Warden `Deceiver` / `Architect` tree copy aligned to trickster powers.
4. `docs/PLAYTEST.md` — Chime act script, balance knobs.
5. Integration: `tests/integration/test_chime_act_flow.gd`

**Exit criteria**

- Full 3+1 session: 3 acts, mixed Warden pranks, dual scoreboard, `make test` green.

---

## Suggested timeline (dependency order)

```
T1 Chime shell
    ↓
T2 Cut/open ──→ T4 False wall
    ↓              ↓
T3 Fling trap ─────┴──→ T5 Dual win
                            ↓
                       T6 Polish
```

T2 and T3 can partially parallelize after T1.

---

## Balance knobs (export / config)

| Knob | Default (starting point) |
|------|---------------------------|
| `match_duration_sec` | 1200 (20 min) |
| `act_duration_sec` | 360–420 per act |
| `chime_ping_interval_sec` | 3.5 |
| `chime_hold_reveal_sec` | 2.0 |
| `chime_deliver_channel_sec` | 4.0 |
| `mutation_ttl_sec` | 30 |
| `false_wall_ttl_sec` | 40 |
| `false_wall_max_active` | 3 |
| `fling_stun_sec` | 0.75 |
| `warden_chime_speed_multiplier` | 0.85 |
| `spectacle_win_threshold` | Tune in playtest |

---

## Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Mesh patch desync | Server owns grid; clients apply same patch id |
| Fling net jitter | Server authoritative launch; client interpolate arc |
| False wall grief (hard lock) | Placement validator + punch interact |
| Chime camping | Escalating ping; act timer; Warden steal |
| Warden feels weak if apprentices always win | Spectacle + Director's Cut + time tax |
| Voice scream detection flaky | Spectacle optional; fling witness uses position not RMS |

---

## Relationship to existing plan

| [`ASYMMETRIC_HORROR_PLAN.md`](ASYMMETRIC_HORROR_PLAN.md) | This plan |
|----------------------------------------------------------|-----------|
| Phase 5 Warden (Seal, Fog, Whisper) | **Superseded in tone** — keep Whisper; defer Fog; Seal rare |
| Phase 4 Co-op puzzles | Still valid; optional anchor inside Act 2 |
| Phase 3 Sealed | Still valid; Chime drops on seal |
| `warden_skill_tree.tres` | Reframe **Deceiver + Architect** as trickster paths; Hunter optional |

When Phase T5 lands, update parent plan Phase 5 exit criteria to reference this document.

---

*Last updated: 2026-07-03 — trickster Warden, Chime acts, fling / cut / false wall, dual win.*
