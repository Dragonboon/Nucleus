# World Surfaces Contract

`addons/nucleus/components/world/surfaces` exposes two separate contracts:

```text
semantic classification
    what kind of surface was hit?

spatial sampling
    where is a continuous height-field surface and how is it moving?
```

There is no surface manager or Autoload.

## Semantic classification

`NucleusSurfaceProfile` contains a stable `surface_id` and semantic tags. Static
providers can live near collision geometry; `NucleusSurfaceResolver3D` resolves
shape-owner, collider and ancestor scopes in priority order from an existing
Godot collision result.

The resolver does not perform a second raycast and does not own footstep/decal/VFX
content selection.

`NucleusSurfaceSource3D` is the extension point for position-dependent semantics
such as procedural layers or runtime masks.

## Spatial sampling

`NucleusSurfaceSampler3D` models a single-valued world-X/Z surface. A successful
`NucleusSurfaceSample3D` contains world-space position, normal, surface velocity,
sampled time and optional adapter metadata.

Use `sample()` for convenience and `sample_into()` with a reusable result in hot
paths such as buoyancy.

The built-in `NucleusPlaneSurfaceSampler3D` is the minimal concrete sampler.
Projects can implement analytical ocean/river/other height-field samplers without
moving their wave/content policy into Nucleus.

## Terrain integration

The optional terrain module provides `NucleusTerrainSurfaceSampler3D` over the
same analytical height source used by its generator. It does not need to raycast
generated collision.

Runtime terrain-stream sampling policy remains separate because loaded/unloaded
region semantics are product-specific.

## Buoyancy integration

`NucleusBuoyancy3D` is an existing consumer of `NucleusSurfaceSampler3D`:

```text
SurfaceSampler3D
    position + normal + surface velocity
        ↓
NucleusBuoyancy3D
        ↓
native RigidBody3D
```

Fluid density, hull samples and solver tuning are owned by the buoyancy component
and game configuration, not by the surface sampler.

The same sampler may also serve swimming height, VFX placement, camera constraints
or AI queries when those systems need the same analytical field.

## Persistence / networking / performance

Persist stable semantic IDs or authoritative field parameters, not live provider
Nodes. On authoritative multiplayer simulation, sample the authoritative field at
the authoritative simulation time.

There is no polling registry. Semantic resolution runs only when requested;
`sample_into()` avoids per-query result allocation for hot paths.
