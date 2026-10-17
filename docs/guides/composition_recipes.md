# Composition recipes: from a game idea to working Nucleus owners

To ask a coding agent to implement one recipe in small validated steps, use
[agent prompt playbook](agent_prompt_playbook.md) and its
[worked prompt sequences](agent_prompt_examples.md).

This companion to the [use-case catalog](use_case_catalog.md) gives **mechanic-
shaped starting points**. Recipes are intentionally small. They tell a human or
AI where to begin, not which art, combat or progression decisions to hard-code.
The linked contracts contain the real class signatures and Inspector setup.

> [!TIP]
> Pick the closest recipe, open its linked contract, and build one testable
> vertical slice. These examples show **composition**, not drop-in scenes.

## Use cases

### 1. A door that opens and remains open after reload

**Components:** native `Area3D` or ray interaction, Nucleus interaction,
`NucleusSave`/World State. **Game owns:** door eligibility, animation, sound,
unique persistent ID and closed/open rules.

1. Define a stable door ID and a versioned `{open: bool}` document.
2. Observe interaction in the native scene. Reject out-of-range/locked requests.
3. Change the door state in the game owner, then play AnimationTree/AnimationPlayer.
4. Capture and restore through the documented save/world-state boundary.
5. Test new game, save, reload, duplicate IDs and a rejected locked-door action.

Read [interaction](../components/gameplay_foundation.md),
[world state](../modules/persistent_world_state.md), and
[save](../components/save_system.md).

### 2. A stamina-limited dodge or sprint

**Components:** semantic input, value pool, gameplay action/timing, native
CharacterBody motor and AnimationTree. **Game owns:** stamina cost, speed,
invulnerability and cooldown.

1. Keep one motor authority each physics tick.
2. Feed an action request from semantic input, checking resource/cooldown first.
3. Subtract stamina only after action admission; drive the motor and feedback.
4. Restore stamina through the neutral regeneration component if needed.
5. Test zero stamina, input remapping, pause, interrupted dodge and save scope.

Read [movement](../components/gameplay_movement_camera.md),
[actions](../components/gameplay_actions_attributes_status.md) and
[gameplay foundations](../components/gameplay_foundation.md).

### 3. Enemies that patrol, detect, pursue and disengage

**Components:** native NavigationAgent, AI utilities, target sensing and FSM.
**Game owns:** patrol graph, perception rules, relationships, tactics, attacks.

1. Start with deterministic decision fixtures before adding animations.
2. Use existing target filters/scorers and guard against vanished targets.
3. Stagger low-priority decision updates; keep navigation movement frame-correct.
4. Drive animation from accepted state, not from competing position writers.
5. Test target loss, unreachable path, occlusion, authority and large NPC count.

Read [AI](../modules/ai_navigation.md),
[targeting](../components/gameplay_pooling_targeting.md) and
[runtime scheduling](../components/runtime_optimization.md).

### 4. An inventory with pickups, loot and equipment

**Components:** Inventory/Equipment, deterministic Loot, Save, interaction.
**Game owns:** item catalog, rarity, capacity, UI, item effects and economy.

1. Choose stable item IDs and an inventory/equipment schema.
2. Roll rewards on the game authority; validate pickup and capacity before mutation.
3. Notify UI after accepted state changes; store only durable data.
4. Test full inventory, duplicate pickup, equip restrictions and save migration.

Read [inventory](../modules/inventory_equipment.md),
[loot](../modules/probability_loot.md), [UI bindings](../components/ui_runtime_bindings.md).

### 5. A procedural world with hills, density masks and streaming

**Components:** Terrain heightmap processor, WorldMask3D, Scatter,
WorldStreamLifecycle and MaterializationQueue. **Game owns:** biomes, island
shape recipes, streaming radius, species, climate and spawn logic.

1. Create deterministic, versioned world/region descriptors.
2. Apply authored noise/heightmap shaping, then slope constraints where warranted.
3. Feed materialized terrain to visual/collision owners and real surface queries.
4. Consult the world mask for game-owned scatter density rules.
5. Stream only the needed visual/physical regions; keep persistent descriptors.
6. Test reproducible seeds, teleport across cells, collision readiness and budgets.

Read [terrain](../modules/terrain_generation.md),
[slope](../modules/terrain_heightfield_constraints.md),
[fields](../components/world_fields.md),
[scatter](../modules/scatter_generation.md),
[streaming](../components/world_streaming.md).

### 6. A boat floating on animated water

**Components:** analytical SurfaceSampler3D, Buoyancy3D, native rigid body.
**Game owns:** wave simulation, steering, boarding, wake appearance and sounds.

1. Expose the water's physical height/normal/velocity through a sampler adapter.
2. Give hull buoyancy one authoritative physics owner.
3. Sample at the simulation time, not arbitrary shader visual displacement.
4. Emit optional presentation stamps only for real motion and meaningful contacts.
5. Test water-shore-water transitions, stable idle hull and physics under waves.

Read [surface sampling](../components/world_surfaces.md),
[buoyancy](../components/world_buoyancy.md) and
[transient marks](../components/world_feedback.md).

### 7. Floating NPC nameplates in a crowded world

**Components:** Nucleus world-space anchors and label layout. **Game owns:**
label visibility permissions, name/team style, health source and occlusion policy.

1. Bind each label to one valid Node3D and a `Control` scene.
2. Supply the active camera; avoid updating all distant labels every frame.
3. Use layout overlap constraints and explicitly hide unplaceable labels.
4. Test behind-camera, offscreen, deep distance, camera changes, crowded actors.

Read [world anchors](../components/ui_world_anchors.md) and
[UI accessibility](../components/ui_and_accessibility.md).

### 8. Multiplayer players that do not replicate the whole map

**Components:** networking bootstrap, server-owned intent validation, native
Spawner/Synchronizer, transform snapshots, spatial interest management, recovery.
**Game owns:** authentication, ownership, authorized visibility and game state.

1. Establish a transport and authenticate the session; never trust client positions.
2. Spawn network actors via native Godot APIs on the authoritative peer.
3. Validate gameplay intents separately from transport-level shape/rate checks.
4. Select candidate interest on the server and authorize every visibility change.
5. Restore identity and relevant state after reconnect; handle stale messages.
6. Test two clients and a server, packet loss, teleport, reconnect and despawn.

Read [replication](../modules/online_replication.md),
[interest](../modules/network_interest_management.md) and
[recovery](../modules/network_recovery.md).

### 9. A puzzle or editor with undo that may fail restoration

**Components:** native `UndoRedo` for reversible commands; optional validated
snapshot history for runtime data restoration. **Game owns:** snapshot schema,
validation, atomic application and canceling animations.

1. Record a single complete action, not each drag-frame delta.
2. For snapshots, peek the candidate without changing the history cursor.
3. Validate/restore on the owning model; acknowledge only after success.
4. Reject stale tickets and disallow partial restores.
5. Test Redo branch invalidation, bounded history, corrupted data, active tween.

Read [history](../components/validated_action_history.md).

### 10. A Godot editor placing modular scenes without destroying author work

**Components:** packed scene preflight, native EditorUndoRedoManager, validated
resources and scene ownership. **Addon owns:** placement constraints, stable IDs,
collision checks and generated preview lifecycle.

1. Inspect trusted authored scenes without instantiating for cheap early checks.
2. Build candidate data on a copy and run structural/physical validation.
3. Compile preview before committing; preserve user nodes and ownership.
4. Commit one native do/undo action only when all preconditions pass.
5. Test undo, redo, save/reopen, nested PackedScene ownership and rejection.

Read [preflight](../modules/packed_scene_preflight.md) and
[development validation](../modules/development_tools.md).

### 11. A 2D level editor that selects overlapping thousands of objects

**Components:** SpatialRectIndex2D plus exact object hit testing.
**Editor owns:** stable IDs, z-order, actual selection and accessibility margin.

1. Register each object's current bounding rectangle and display priority.
2. Query point/region on input; test precise shape only for returned candidates.
3. Update/remap the index when objects move, resize or are removed.
4. Test negative coordinates, boundaries, extreme zoom and draw order.

Read [2D index](../components/spatial_rect_index_2d.md).

### 12. A game that stutters when lots of content appears

**Components:** NucleusPerformanceSampler, optional section profiling,
materialization queues, warmup and scheduling. **Game owns:** frame-time budget
and acceptable latency for low-priority jobs.

1. Capture the same workload before changing quality or scheduling.
2. Identify CPU, GPU, resource loading or physics evidence using native tools.
3. Use exactly one bounded intervention, retaining correctness and ownership.
4. Compare captures under matching target renderer/hardware.
5. Report frame-time p95/p99 if measured, and any behavior regressions.

Read [performance](../modules/performance.md),
[sections](../modules/performance_sections.md) and
[runtime optimization](../components/runtime_optimization.md).

## What to do when no recipe matches

Write the game-owned behavior, then search native Godot and the
[capability catalog](use_case_catalog.md). Ask whether the difference is a
reusable **mechanism** or product-specific **policy**. Build it locally first;
add a new Nucleus contract only when the maintenance and reuse case is clear.


### Compose a board, tactical or RPG turn with actions

**Components:** [Turn session](../components/turn_sessions.md),
[Gameplay Actions](../components/gameplay_actions_attributes_status.md),
[status clocks](../components/turn_sessions.md).
**Game owns:** legal moves, targeting, scoring, winning, authority and UI.

1. Create a `NucleusTurnSession` and participant per player, enemy or seat.
2. Add a `NucleusTurnRequirement` to any action restricted to that seat.
3. Put `NucleusFinishTurnEffect` last if completing the action advances the turn.
4. Choose `DurationUnit.TURNS` and a single `NucleusTurnStatusBinding` if
   statuses should expire by owner turns or completed rounds.
5. Run `turn_composition_test.gd` and the full project headless suite.
6. See the [turns quickstart](turns_composition_quickstart.md) for practical code.
