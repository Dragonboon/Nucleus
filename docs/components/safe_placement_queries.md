# Safe Placement Queries Contract

## Scope

Nucleus exposes stateless 2D/3D helpers for one recurring question:

> Can this collision shape occupy this transform without overlapping existing
> physics objects?

Public types:

```text
NucleusPlacementQueries2D
NucleusPlacementQueries3D
```

They live beside the movement foundation because they help movement transitions
without owning spawning, teleportation, vehicles, checkpoints or world rules.

## Why shape queries

A point or ray can report an apparently valid position even when the actual
character capsule, vehicle occupant, NPC body or interactable shape would overlap
geometry there.

Safe placement uses the real `Shape2D`/`Shape3D` and native Godot
`PhysicsDirectSpaceState.intersect_shape()`.

Typical consumers include:

```text
spawn / respawn
vehicle disembark
teleport / portals
revive
fast travel
ladder/elevator exits
companion placement
NPC placement
```

## Basic 3D flow

Build candidate transforms in game-owned priority order:

```gdscript
var candidates: Array[Transform3D] = [
	Transform3D(player.global_basis, exit_a),
	Transform3D(player.global_basis, exit_b),
	Transform3D(player.global_basis, exit_c),
]

var excluded: Array[RID] = [player.get_rid()]
var index := NucleusPlacementQueries3D.find_first_free_index(
	player.get_world_3d().direct_space_state,
	player_collision.shape,
	candidates,
	player.collision_mask,
	excluded,
)

if index >= 0:
	player.global_transform = candidates[index]
	player.reset_physics_interpolation()
```

The helper returns only the candidate index. The game keeps ownership of what
each candidate means and what happens when no candidate is free.

## Query controls

Both dimensions support:

```text
collision_mask
exclude RIDs
collide_with_bodies
collide_with_areas
margin
```

`is_transform_free()` is useful when the game already has one candidate.
`find_first_free_index()` tests an ordered candidate list and stops at the first
free transform.

Invalid or missing query dependencies are treated as unsafe.

## Boundaries

Nucleus does not:

```text
invent candidate positions
snap to navigation
sample terrain/water automatically
move the actor
change collision layers
disable collisions while searching
choose respawn/checkpoint policy
guarantee gameplay reachability after placement
```

Compose other systems explicitly when required. For example, a game can use a
surface sampler to generate candidate heights and Safe Placement to verify the
final collision shape.

## Performance

`find_first_free_index()` reuses one native query object across the candidate
list and requests at most one intersection result per candidate.

Keep candidate lists small and ordered by desirability. This is intended for
transitions and placement events, not for scanning thousands of positions every
physics frame.

## Runtime asset placement (optional composition)

The independent [Runtime Placement 3D Contract](runtime_placement_3d.md)
composes this **existing stateless collision query** with explicit surface
admission, authored stack permissions, bounded straight-line chain placement
and move/rotate preview sessions. Its collision-layer changes apply **only to
temporary placeable previews**, never to this stateless query API. It remains
scene-owned; construction rules and multiplayer authority belong to the game.
