# Spatial Rect Index 2D (P04)

Target engine: Godot 4.7.2. Source:
`addons/nucleus/core/utils/geometry/spatial_rect_index_2d.gd`.

`NucleusSpatialRectIndex2D` is a generic, mutable, scene-independent **broad
phase** for rectangular areas. It does not touch the physics server or receive
input; callers still own polygon/shape hit tests, UI visibility, accessibility,
or the authoritative selection decision.

```gdscript
var index := NucleusSpatialRectIndex2D.new()
index.configure_cell_size(64.0)
index.upsert(101, Rect2(0, 0, 80, 40), 5)
index.upsert(202, Rect2(20, 20, 60, 40), 10)

# IDs ordered from highest draw_order to lowest, then highest ID.
var candidates: Array[int] = index.query_point(Vector2(35, 30))
var nearby: Array[int] = index.query_region(Rect2(0, 0, 100, 100))

index.remove(101)
index.clear()
```

> [!TIP]
> **Use for:** broad-phase 2D hit candidates and large selection areas.
> **Not for:** exact shape intersection, physics, or network visibility.

## Index semantics

- IDs are nonnegative integers supplied by the caller, never Godot instance
  IDs unless that is explicitly the caller's stable-lifetime policy.
- `upsert` updates a prior rectangle and removes its old spatial membership.
- `Rect2` position/size must be finite and dimensions nonnegative.
- Cell coordinates use `floor`, including negative X/Y positions.
- Point queries use `Rect2.has_point()` (positive end is exclusive).
- Region queries use `Rect2.intersects()` with **inclusive borders by default**;
  pass `false` to use strictly overlapping rectangles.
- Query results are exact rectangular candidates ordered by descending
  `draw_order`, then descending ID; polygon/narrow-phase testing remains external.
- `configure_cell_size` retains entries and rebuilds their buckets.

## Bounded broad phase

`max_cells_per_item` (default 1024) prevents very large rectangles from
occupying arbitrarily many buckets. Such entries live in an overflow list and
are still tested for every query. `max_query_cells` (default 4096) bounds
enumeration of query cells; a huge query scans stored entries directly. Thus
oversized operations trade runtime for bounded bucket allocation, rather than
silently omitting candidates.

An extremely dense index can still cost O(N) per query. Reuse the same index
across updates; avoid rebuilding it per mouse event. This helper is not an
R-tree, a spatial partition for networking, or a physics broad phase.

## Use cases

| Scenario | Good fit | Not the responsibility of this index |
| --- | --- | --- |
| Hundreds of draggable items on a 2D workbench | Keep bounding rectangles current and query only nearby candidates | Exact rotated/polygon hit tests |
| Selecting many nodes inside a map-editor marquee | Query candidates by `Rect2` before applying selection rules | Editor selection history and hidden/locked filters |
| Controller or accessible pointer with hit margin | Query an expanded input region, then verify actual shape | Input assist policy and UI focus |

Use native physics querying for collidable bodies. Use the network 3D interest
index for authoritative peer visibility; this 2D index is neither of those.

## Caller-owned query storage

`query_region_into(region, result, scratch, include_borders=true,
sorted_results=true)` clears/reuses caller-owned `Array[int]` and `Dictionary`.
It retains the complete exact rectangle candidate set, including overflow and
large-query fallback. Default ordering matches `query_region`; disabling sorting
is explicit. Do not share scratch during concurrent/reentrant queries. See the
[runtime workload contract](runtime_optimization.md) for composition and limits.
