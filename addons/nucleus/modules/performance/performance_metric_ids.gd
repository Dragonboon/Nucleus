class_name NucleusPerformanceMetricIds
extends RefCounted
## Stable metric IDs emitted by NucleusPerformanceSampler.

const FPS: StringName = &"time/fps"
const PROCESS_MS: StringName = &"time/process_ms"
const PHYSICS_MS: StringName = &"time/physics_ms"
const NAVIGATION_MS: StringName = &"time/navigation_ms"

## Effective FPS measured from monotonic process-frame timestamps.
const WINDOW_FPS: StringName = &"time/window_fps"
## Mean wall-clock frame interval during the sampling window.
const FRAME_INTERVAL_AVG_MS: StringName = &"time/frame_interval_avg_ms"
## Median wall-clock frame interval during the sampling window.
const FRAME_INTERVAL_P50_MS: StringName = &"time/frame_interval_p50_ms"
## 95th percentile wall-clock frame interval during the sampling window.
const FRAME_INTERVAL_P95_MS: StringName = &"time/frame_interval_p95_ms"
## Slowest wall-clock frame interval during the sampling window.
const FRAME_INTERVAL_MAX_MS: StringName = &"time/frame_interval_max_ms"
## Number of per-frame deltas used to build the pacing sample.
const FRAME_INTERVAL_SAMPLES: StringName = &"time/frame_interval_samples"

const STATIC_MEMORY_BYTES: StringName = &"memory/static_bytes"
const MESSAGE_BUFFER_MAX_BYTES: StringName = &"memory/message_buffer_max_bytes"

const OBJECT_COUNT: StringName = &"objects/total"
const RESOURCE_COUNT: StringName = &"objects/resources"
const NODE_COUNT: StringName = &"objects/nodes"
const ORPHAN_NODE_COUNT: StringName = &"objects/orphan_nodes"

const RENDER_OBJECTS: StringName = &"render/objects"
const RENDER_PRIMITIVES: StringName = &"render/primitives"
const RENDER_DRAW_CALLS: StringName = &"render/draw_calls"
const VIDEO_MEMORY_BYTES: StringName = &"render/video_memory_bytes"
const TEXTURE_MEMORY_BYTES: StringName = &"render/texture_memory_bytes"
const BUFFER_MEMORY_BYTES: StringName = &"render/buffer_memory_bytes"

const PHYSICS_2D_ACTIVE: StringName = &"physics_2d/active_objects"
const PHYSICS_2D_PAIRS: StringName = &"physics_2d/collision_pairs"
const PHYSICS_2D_ISLANDS: StringName = &"physics_2d/islands"

const PHYSICS_3D_ACTIVE: StringName = &"physics_3d/active_objects"
const PHYSICS_3D_PAIRS: StringName = &"physics_3d/collision_pairs"
const PHYSICS_3D_ISLANDS: StringName = &"physics_3d/islands"

const NAVIGATION_2D_REGIONS: StringName = &"navigation_2d/regions"
const NAVIGATION_2D_AGENTS: StringName = &"navigation_2d/agents"
const NAVIGATION_2D_OBSTACLES: StringName = &"navigation_2d/obstacles"

const NAVIGATION_3D_REGIONS: StringName = &"navigation_3d/regions"
const NAVIGATION_3D_AGENTS: StringName = &"navigation_3d/agents"
const NAVIGATION_3D_OBSTACLES: StringName = &"navigation_3d/obstacles"

const PIPELINE_CANVAS: StringName = &"pipelines/canvas"
const PIPELINE_MESH: StringName = &"pipelines/mesh"
const PIPELINE_SURFACE: StringName = &"pipelines/surface"
const PIPELINE_DRAW: StringName = &"pipelines/draw"
const PIPELINE_SPECIALIZATION: StringName = &"pipelines/specialization"
