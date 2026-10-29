@tool
class_name NucleusSmartDecal3D
extends Decal
## Surface-aligned runtime decal with optional variation, fade, and pool release.
##
## Godot Decal projects from local +Y toward local -Y. Nucleus aligns local Y
## with the outward surface normal so projection travels into the hit surface.

signal placed(world_position: Vector3, surface_normal: Vector3)
signal expired

@export_group("Placement")
@export_range(0.0, 1.0, 0.0001, "or_greater")
var surface_offset: float = 0.001

@export var randomize_roll: bool = true:
	set(value):
		randomize_roll = value
		update_configuration_warnings()

@export_range(-360.0, 360.0, 0.1, "degrees")
var minimum_roll_degrees: float = 0.0:
	set(value):
		minimum_roll_degrees = value
		update_configuration_warnings()

@export_range(-360.0, 360.0, 0.1, "degrees")
var maximum_roll_degrees: float = 360.0:
	set(value):
		maximum_roll_degrees = value
		update_configuration_warnings()

@export_group("Planar size variation")
@export var randomize_planar_scale: bool = false:
	set(value):
		randomize_planar_scale = value
		update_configuration_warnings()

@export_range(0.001, 100.0, 0.001, "or_greater")
var minimum_planar_scale: float = 0.85:
	set(value):
		minimum_planar_scale = value
		update_configuration_warnings()

@export_range(0.001, 100.0, 0.001, "or_greater")
var maximum_planar_scale: float = 1.15:
	set(value):
		maximum_planar_scale = value
		update_configuration_warnings()

@export var uniform_planar_scale: bool = true

@export_group("Lifetime")
@export_range(0.0, 3600.0, 0.01, "or_greater")
var fade_after: float = 0.0

@export_range(0.0, 3600.0, 0.01, "or_greater")
var fade_duration: float = 1.0

@export var start_lifetime_on_ready: bool = false
@export var free_on_expire: bool = true

@export_group("Pooling")
@export var poolable: NucleusPoolable:
	set(value):
		poolable = value
		update_configuration_warnings()

@export var release_poolable_on_expire: bool = true

var _baseline_captured: bool = false
var _baseline_size: Vector3
var _baseline_modulate: Color
var _baseline_emission_energy: float
var _lifetime_tween: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_capture_baseline(false)
	_resolve_poolable()
	_connect_poolable()

	if start_lifetime_on_ready and fade_after > 0.0:
		start_lifetime()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return

	cancel_lifetime()
	_disconnect_poolable()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if texture_albedo == null and texture_emission == null:
		warnings.append(
			"Assign texture_albedo or texture_emission so the decal is visible."
		)

	if (
		randomize_planar_scale
		and maximum_planar_scale < minimum_planar_scale
	):
		warnings.append(
			"maximum_planar_scale must be greater than or equal to "
			+ "minimum_planar_scale."
		)

	if randomize_roll and maximum_roll_degrees < minimum_roll_degrees:
		warnings.append(
			"maximum_roll_degrees must be greater than or equal to "
			+ "minimum_roll_degrees."
		)

	return warnings


## Builds a world-space basis whose local +Y points along [param surface_normal].
##
## [param tangent_hint] optionally controls local +X and therefore decal roll.
static func build_surface_basis(
	surface_normal: Vector3,
	tangent_hint: Vector3 = Vector3.ZERO,
) -> Basis:
	if surface_normal.is_zero_approx():
		return Basis.IDENTITY

	var normal: Vector3 = surface_normal.normalized()
	var tangent: Vector3 = (
		tangent_hint
		- normal * tangent_hint.dot(normal)
	)

	if tangent.is_zero_approx():
		var reference := Vector3.RIGHT

		if absf(normal.dot(reference)) > 0.999:
			reference = Vector3.FORWARD

		tangent = (
			reference
			- normal * reference.dot(normal)
		)

	tangent = tangent.normalized()
	var bitangent: Vector3 = tangent.cross(normal).normalized()

	return Basis(
		tangent,
		normal,
		bitangent,
	).orthonormalized()


## Rotates the decal so its projector points into the supplied surface.
func align_to_surface(
	surface_normal: Vector3,
	tangent_hint: Vector3 = Vector3.ZERO,
	apply_random_roll: bool = false,
) -> Error:
	if surface_normal.is_zero_approx():
		return ERR_INVALID_PARAMETER

	global_basis = build_surface_basis(
		surface_normal,
		tangent_hint,
	)

	if apply_random_roll:
		_apply_roll_randomization()

	return OK


## Places and optionally randomizes this decal at a world-space surface hit.
func place_on_surface(
	world_position: Vector3,
	surface_normal: Vector3,
	tangent_hint: Vector3 = Vector3.ZERO,
	apply_randomization: bool = true,
	restart_lifetime: bool = true,
) -> Error:
	if surface_normal.is_zero_approx():
		return ERR_INVALID_PARAMETER

	_ensure_baseline()
	reset_visual_state()

	var normal: Vector3 = surface_normal.normalized()
	var target_basis: Basis = build_surface_basis(
		normal,
		tangent_hint,
	)

	global_transform = Transform3D(
		target_basis,
		world_position + normal * surface_offset,
	)

	if apply_randomization:
		_apply_planar_scale_randomization()
		_apply_roll_randomization()

	if restart_lifetime and fade_after > 0.0:
		start_lifetime()

	placed.emit(
		global_position,
		normal,
	)

	return OK


## Restores visual state captured from the configured scene/resource defaults.
func reset_visual_state() -> void:
	_ensure_baseline()
	cancel_lifetime()

	size = _baseline_size
	modulate = _baseline_modulate
	emission_energy = _baseline_emission_energy
	visible = true


## Replaces the visual baseline used by reset/randomization.
func recapture_visual_baseline() -> void:
	_capture_baseline(true)


## Starts the configured visible delay followed by an optional alpha/emission fade.
func start_lifetime(
	custom_fade_after: float = -1.0,
	custom_fade_duration: float = -1.0,
) -> void:
	cancel_lifetime()

	var delay: float = (
		custom_fade_after
		if custom_fade_after >= 0.0
		else fade_after
	)

	if delay <= 0.0:
		return

	var duration: float = (
		custom_fade_duration
		if custom_fade_duration >= 0.0
		else fade_duration
	)

	_lifetime_tween = create_tween()
	_lifetime_tween.tween_interval(delay)

	if duration > 0.0:
		_lifetime_tween.tween_property(
			self,
			"modulate:a",
			0.0,
			duration,
		)

		if texture_emission != null:
			_lifetime_tween.parallel().tween_property(
				self,
				"emission_energy",
				0.0,
				duration,
			)

	_lifetime_tween.tween_callback(_expire)


func cancel_lifetime() -> void:
	if _lifetime_tween == null:
		return

	if _lifetime_tween.is_valid():
		_lifetime_tween.kill()

	_lifetime_tween = null


func _apply_planar_scale_randomization() -> void:
	if not randomize_planar_scale:
		return

	var scale_x: float = randf_range(
		minimum_planar_scale,
		maximum_planar_scale,
	)
	var scale_z: float = scale_x

	if not uniform_planar_scale:
		scale_z = randf_range(
			minimum_planar_scale,
			maximum_planar_scale,
		)

	size.x = _baseline_size.x * scale_x
	size.z = _baseline_size.z * scale_z


func _apply_roll_randomization() -> void:
	if not randomize_roll:
		return

	var angle_degrees: float = randf_range(
		minimum_roll_degrees,
		maximum_roll_degrees,
	)
	rotate_object_local(
		Vector3.UP,
		deg_to_rad(angle_degrees),
	)


func _expire() -> void:
	_lifetime_tween = null
	expired.emit()

	if (
		release_poolable_on_expire
		and poolable != null
		and poolable.is_active()
	):
		var release_error: Error = poolable.request_release()

		if release_error == OK:
			return

	if free_on_expire:
		queue_free()
	else:
		visible = false


func _capture_baseline(force: bool) -> void:
	if _baseline_captured and not force:
		return

	_baseline_size = size
	_baseline_modulate = modulate
	_baseline_emission_energy = emission_energy
	_baseline_captured = true


func _ensure_baseline() -> void:
	if not _baseline_captured:
		_capture_baseline(false)


func _resolve_poolable() -> void:
	if poolable != null:
		return

	for child: Node in get_children():
		if child is NucleusPoolable:
			poolable = child as NucleusPoolable
			return


func _connect_poolable() -> void:
	if poolable == null:
		return

	if not poolable.acquired.is_connected(_on_poolable_acquired):
		poolable.acquired.connect(_on_poolable_acquired)

	if not poolable.released.is_connected(_on_poolable_released):
		poolable.released.connect(_on_poolable_released)


func _disconnect_poolable() -> void:
	if poolable == null or not is_instance_valid(poolable):
		return

	if poolable.acquired.is_connected(_on_poolable_acquired):
		poolable.acquired.disconnect(_on_poolable_acquired)

	if poolable.released.is_connected(_on_poolable_released):
		poolable.released.disconnect(_on_poolable_released)


func _on_poolable_acquired(_context: Dictionary) -> void:
	reset_visual_state()


func _on_poolable_released() -> void:
	cancel_lifetime()
