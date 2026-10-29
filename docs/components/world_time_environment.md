# World Time and Environment Contract

Target engine: Godot 4.7.x.

## Scope

```text
addons/nucleus/components/world/time
addons/nucleus/components/world/environment
```

These components provide a scene-owned simulation clock, coarse day-period
classification, native Godot daylight presentation, and localized environmental
FX infrastructure.

They do not create a global world manager, weather manager, or FX manager.

## Ownership

The intended dependency direction for world time is:

```text
NucleusWorldClock
    simulation time only
        ↓
NucleusDayPeriodClassifier
    semantic dawn/day/dusk/night state

NucleusWorldClock
        ↓
NucleusDaylightDriver3D
        ↓
DirectionalLight3D / WorldEnvironment
```

The clock does not know that lights, skies, weather, NPCs, spawning, or saves
exist. Consumers observe or query it.

Localized FX use a separate composition:

```text
NucleusLocalFxVolume3D
    follow + intensity + quality
        ↓
NucleusGpuParticlesFxBinding3D
        ↓
native GPUParticles3D
```

Sparse secondary effects may additionally consume `NucleusFxSpawnBudget`.
Neither path depends on the world clock.

This separation is deliberate. A headless server can own the clock without any
rendering nodes, while clients can independently own visual environment effects.

## NucleusWorldClock

`NucleusWorldClock` models a fixed 24-hour logical day:

```text
24 hours
1440 minutes
86400 game seconds
```

`day` is a zero-based logical day index, not a calendar date.

The clock stores:

```text
day
seconds_of_day
running
game_seconds_per_real_second
```

It exposes three advancement modes:

```text
IDLE
    advance from _process(delta)

PHYSICS
    advance from _physics_process(delta)

MANUAL
    never advances itself
```

`MANUAL` is the preferred mode when another authority owns simulation time, for
example a dedicated server tick, replay system, deterministic simulation, or
network snapshot.

### Time scale

`game_seconds_per_real_second` converts Godot delta into game time.

Examples:

```text
1.0     real time
60.0    one game minute per real second
3600.0  one game hour per real second
```

The automatic modes intentionally consume Godot's normal process/physics delta.
They therefore follow the SceneTree pause/process policy and engine time scale.
If a project needs a clock independent of those policies, use `MANUAL` and call
`advance_game_seconds()` from the owner of that simulation.

### Setting and querying time

Useful public methods:

```gdscript
clock.set_time_hms(3, 18, 30)
clock.advance_game_seconds(90.0)

var day := clock.get_day()
var hour := clock.get_hour()
var minute := clock.get_minute()
var normalized := clock.get_normalized_day_time()
```

`normalized` is in the range `0.0 .. 1.0` within the current day.

`set_total_game_seconds()` and `get_total_game_seconds()` are useful when a game
persists or replicates a single absolute simulation-time value.

Negative total time is clamped to zero. `set_time_hms()` rejects invalid day,
hour, minute, or second fields instead of silently wrapping malformed input.

### Signals and large jumps

The clock emits:

```text
time_changed
day_changed
hour_changed
minute_changed
running_changed
time_scale_changed
```

A large jump reports the previous and final values once. It does **not** emit one
signal for every skipped minute/hour/day.

This is important for loading saves, sleeping until morning, fast travel, or
server correction. Systems that must process every elapsed interval should own
that simulation explicitly rather than infer work from UI-oriented clock
signals.

## Persistence

`capture_state()` returns stable plain data and `restore_state()` validates it.
The captured schema contains:

```text
schema_version
day
seconds_of_day
running
game_seconds_per_real_second
```

The clock does not write files and does not register itself with `NucleusSave`.
The consuming game's save document decides whether world time is durable.

Example shape:

```gdscript
save_document["world_clock"] = clock.capture_state()

# after loading
clock.restore_state(save_document.get("world_clock", {}))
```

Calendars, named weekdays, seasons, moon phases, holidays, and game-specific
schedule data remain game-owned.

## NucleusDayPeriodClassifier

`NucleusDayPeriodClassifier` maps the clock to four coarse semantic periods:

```text
DAWN
DAY
DUSK
NIGHT
```

Default boundaries are:

```text
dawn  05:00
day   07:00
dusk  18:00
night 21:00
```

They are configurable in decimal hours and must satisfy:

```text
dawn < day < dusk < night
```

Night wraps across midnight automatically.

The classifier is intentionally small. It is useful for rules such as:

```text
activate street lamps at night
change ambient audio at dusk
open a shop during the day
select spawn tables by period
```

It does not drive rendering and it does not own arbitrary schedules.

A classifier can be a child of its clock and auto-resolve that parent, or it can
receive an explicit `clock` reference.

## NucleusDaylightProfile

`NucleusDaylightProfile` is reusable presentation data for a 3D daylight driver.
It defines:

```text
sun energy/color/orbit offsets
moon energy/color/orbit offsets
optional shadow gating
background energy
ambient energy
```

Optional `Curve` resources are sampled over normalized day time. Curve output is
interpreted as a normalized `0..1` response and clamped before application.

When no curves are assigned, the profile uses a cheap analytical fallback:

```text
sun peaks at noon
moon peaks at midnight
background/ambient interpolate between night and day values
```

Color gradients are optional. Missing gradients preserve neutral white light.
This avoids embedding an art direction in Nucleus.

## NucleusDaylightDriver3D

`NucleusDaylightDriver3D` is a scene-owned adapter between `NucleusWorldClock`
and native Godot rendering nodes.

It can target any combination of:

```text
DirectionalLight3D sun
DirectionalLight3D moon
WorldEnvironment
```

Every clock change calls `apply_now()` and updates only assigned targets.

The driver writes:

```text
DirectionalLight3D.rotation_degrees
DirectionalLight3D.light_energy
DirectionalLight3D.light_color
DirectionalLight3D.shadow_enabled (optional)
Environment.background_energy_multiplier
Environment.ambient_light_energy
```

It does **not** modify:

```text
sky shader parameters
fog
clouds
weather
post-processing
exposure policy
art-specific celestial meshes
```

Those remain native/project-specific adapters around the clock.

### Typical scene

```text
World
├── WorldClock (NucleusWorldClock)
│   └── Periods (NucleusDayPeriodClassifier)
├── Sun (DirectionalLight3D)
├── Moon (DirectionalLight3D)
├── WorldEnvironment
└── Daylight (NucleusDaylightDriver3D)
```

Assign the same clock to `Daylight.clock`, create a
`NucleusDaylightProfile`, and assign whichever native targets the scene owns.

The driver has editor configuration warnings for missing required references and
for a `WorldEnvironment` without an `Environment` resource.

Disabling the driver stops future writes. It intentionally does not restore an
older light/environment state because ownership of that previous presentation is
not knowable generically.

## Localized environmental FX

Localized FX solve a recurring rendering problem:

> Expensive ambient effects only need to exist around the viewpoint or active
> player, even when the art direction implies they cover a much larger world.

Typical examples include:

```text
rain
snow
ash
sand
pollen
leaves
insects
underwater particles
localized fog/debris particles
```

Nucleus provides orchestration and budgeting only. The project still authors the
actual Godot particle systems, materials, shaders, collision response, and art.

### NucleusLocalFxVolume3D

`NucleusLocalFxVolume3D` owns:

```text
follow target
follow axes
follow offset
smoothed 0..1 intensity
enabled state
LOW / MEDIUM / HIGH quality selection
```

The default follow mask is XZ. This is useful for precipitation where the effect
tracks the player horizontally but keeps an authored world-space height.

Example:

```text
WeatherFx : NucleusLocalFxVolume3D
└── Rain : GPUParticles3D
    └── Binding : NucleusGpuParticlesFxBinding3D
```

Set the `WeatherFx` Y position to the desired emission height and leave Y out of
`follow_axes`. X/Z then follow the target while Y remains unchanged.

For an effect that should follow all movement, enable X/Y/Z.

`follow_offset` applies only to axes that are actually followed.

The volume does not configure particle emission shapes. Use native
`ParticleProcessMaterial`, `GPUParticles3D.visibility_aabb`, lifetime, trails,
materials, and shaders directly.

For precipitation, ash, or similar effects that should leave already-emitted
particles in world space while the emitter follows the player, normally set:

```text
GPUParticles3D.local_coords = false
```

Effects that intentionally move as one local cloud may keep local coordinates.
This remains an authoring decision rather than a hidden Nucleus override.

### Intensity

`intensity` is the target intensity. Runtime consumers should normally change it
through:

```gdscript
volume.set_intensity(0.8)
```

`transition_speed` moves the effective intensity toward that target without
requiring every weather/game system to implement its own fade.

For an immediate change:

```gdscript
volume.set_intensity(0.8, true)
```

`get_current_intensity()` returns zero while the volume is disabled, so bindings
can stop expensive presentation without destroying the effect nodes.

The generic volume does not define what intensity means artistically beyond
`0..1`.

### NucleusGpuParticlesFxBinding3D

The particle binding adapts one native `GPUParticles3D` to the volume.

It owns only:

```text
GPUParticles3D.amount
GPUParticles3D.amount_ratio
GPUParticles3D.emitting
```

The authored `amount` is captured as full-quality capacity unless
`base_amount_override` is set.

Changing particle capacity can make Godot rebuild/restart particle simulation.
Quality changes should therefore be relatively infrequent, such as an options
change or explicit runtime quality transition, not a per-frame adaptation loop.

Do not have another runtime system write those same three properties while the
binding owns them.

The binding deliberately does **not** duplicate or modify:

```text
ParticleProcessMaterial
emission box/sphere/points
gravity
direction
initial velocity
draw-pass materials
visibility AABB
particle lifetime
shader parameters
```

That keeps rain, snow, ash, insects, and project-specific effects native to
Godot instead of turning Nucleus into a particle framework.

### NucleusFxQualityProfile

The quality profile contains two independent multipliers per LOW/MEDIUM/HIGH
tier:

```text
particle_capacity_scale
event_rate_scale
```

Particle capacity scales the full-quality `GPUParticles3D.amount`.

Example for an authored `amount = 1000`:

```text
LOW     0.35 → 350 particles
MEDIUM  0.65 → 650 particles
HIGH    1.00 → 1000 particles
```

Event rate exists for game-owned secondary work such as:

```text
rain-ground impact probes
dust puffs
surface sparks
occasional debris bursts
```

The volume exposes the active value through:

```gdscript
volume.get_event_rate_scale()
```

No automatic quality downgrade is tied to `NucleusPerformance`. Performance
measurement and product quality policy remain separate. A game may connect its
graphics settings to `set_quality()` explicitly.

### NucleusFxSpawnBudget

Sparse effects often need a CPU-side event rate in addition to continuous GPU
particles.

Use one runtime budget per producer:

```gdscript
var impact_budget := NucleusFxSpawnBudget.new(4, 4.0)

func _process(delta: float) -> void:
	var count := impact_budget.advance(
		delta,
		72.0,
		weather_fx.get_current_intensity(),
		weather_fx.get_event_rate_scale(),
	)

	for index: int in range(count):
		spawn_one_ground_impact()
```

The accumulator retains fractional events but clamps backlog. A long frame
therefore cannot queue hundreds of delayed raycasts or impacts for later frames.

When effective rate becomes zero, pending backlog is discarded. Restarting rain,
dust, or another effect therefore cannot replay stale impacts accumulated before
the effect stopped.

`max_events_per_frame` limits immediate CPU work.

`max_backlog_events` limits how much delayed work can survive a spike.

This budget only returns an integer count. It does not cast rays, spawn Nodes,
choose surfaces, or render anything.

### Surface semantics integration

Surface Semantics and Local FX remain independent.

A project-owned rain impact system can compose them:

```text
NucleusLocalFxVolume3D
    intensity + event-rate quality
        ↓
NucleusFxSpawnBudget
        ↓
project raycast
        ↓
NucleusSurfaceResolver3D
        ↓
SurfaceProfile
        ↓
project chooses ground response
```

For example, sand may produce a dark wet speck while metal produces a tiny spark
or audible tick. None of those assets belong in `NucleusSurfaceProfile` or the
generic FX volume.

Water may use a completely different renderer, such as shader-normal
perturbation, without changing the localized volume contract.

### Headless and authority boundary

Localized FX are presentation.

A dedicated server normally does not instantiate the particle binding at all.
If server gameplay needs authoritative weather, it should own the weather state
separately and replicate the relevant semantic state/intensity to clients.

Do not make a gameplay rule authoritative because a client particle system is
currently emitting.

## Multiplayer and authority

Nucleus does not replicate the clock automatically.

Recommended authoritative shape:

```text
server
    owns total game seconds + rate
        ↓
client receives epoch/snapshot
        ↓
client corrects local NucleusWorldClock
        ↓
local presentation observes clock
```

Do not synchronize sun transforms as the source of truth when all clients can
derive them from one authoritative time value and the same presentation profile.

For competitive or simulation-sensitive rules, the authoritative gameplay owner
must query authoritative time. Client daylight is presentation, not authority.

## Performance

`NucleusWorldClock` is constant-time and allocates no per-frame collections.

`NucleusDayPeriodClassifier` only recomputes when clock time changes.

`NucleusDaylightDriver3D` performs direct property writes when time changes. It
does not create viewports, render textures, shaders, or scene-global managers.

`NucleusLocalFxVolume3D` performs constant-time target following and intensity
smoothing. It does not scan scenes or allocate effect instances each frame.

`NucleusGpuParticlesFxBinding3D` changes particle capacity only when quality
changes. Normal intensity updates use native `amount_ratio` and `emitting`.

`NucleusFxSpawnBudget` bounds secondary work instead of allowing delayed spikes
to create unbounded event bursts.

Actual cost still depends on the consuming effect:

```text
particle count
transparent overdraw
screen coverage
material/shader cost
collision queries
shadowing
secondary draw calls
```

Profile the real target hardware. A quality multiplier is a policy knob, not
proof that an effect meets its frame budget.

If a project advances its clock every frame, daylight also updates every frame.
For extremely slow clocks where that is unnecessary, advance the clock at a
lower explicit cadence in `MANUAL` mode.

## What stays game-owned

Nucleus intentionally does not decide:

```text
calendar/date system
seasons and astronomy
weather transitions/state machine
weather probabilities/forecast
wind simulation
rain/snow/ash particle art
particle emission geometry and shaders
surface impact raycasts
surface-specific audio/VFX mappings
water ripple implementation
wetness accumulation
NPC schedules
plant/crop growth
shops opening/closing
sleep mechanics
sunrise/sunset latitude simulation
cloud/sky shader implementation
which systems persist across a new game
network correction/interpolation policy
automatic quality downgrade policy
```

Those systems consume these environment primitives; they do not belong inside
them.
