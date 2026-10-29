class_name NucleusUIMotion
extends RefCounted
## Stateless high-level UI tween helpers.
##
## Tweens are bound to their target, ignore game time scale by default, and
## honor Nucleus accessibility motion settings through their profile.


static func create_tween(
	target: Node,
	profile: NucleusUIMotionProfile = null,
) -> Tween:
	var resolved: NucleusUIMotionProfile = _profile(profile)
	var tween: Tween = target.create_tween()

	tween.set_ignore_time_scale(resolved.ignore_time_scale)
	tween.set_trans(resolved.transition)
	tween.set_ease(resolved.easing)

	return tween


static func get_duration(
	profile: NucleusUIMotionProfile = null,
	multiplier: float = 1.0,
) -> float:
	var resolved: NucleusUIMotionProfile = _profile(profile)

	return NucleusUIMotionPolicy.get_effective_duration(
		resolved.duration * maxf(0.0, multiplier),
		resolved.respect_reduced_motion,
		resolved.reduced_motion_scale,
	)


static func get_effect_amplitude_scale(
	profile: NucleusUIMotionProfile = null,
) -> float:
	var resolved: NucleusUIMotionProfile = _profile(profile)

	return NucleusUIMotionPolicy.get_effect_amplitude_scale(
		resolved.respect_reduced_motion,
		resolved.reduced_motion_scale,
	)


static func fade_to(
	target: CanvasItem,
	alpha: float,
	profile: NucleusUIMotionProfile = null,
) -> Tween:
	var tween: Tween = create_tween(target, profile)

	tween.tween_property(
		target,
		"modulate:a",
		clampf(alpha, 0.0, 1.0),
		get_duration(profile),
	)

	return tween


static func scale_to(
	target: Control,
	scale: Vector2,
	profile: NucleusUIMotionProfile = null,
	pivot_ratio: Vector2 = Vector2(0.5, 0.5),
) -> Tween:
	set_pivot_ratio(target, pivot_ratio)

	var tween: Tween = create_tween(target, profile)
	tween.tween_property(
		target,
		"scale",
		scale,
		get_duration(profile),
	)

	return tween


static func move_to(
	target: Control,
	position: Vector2,
	profile: NucleusUIMotionProfile = null,
) -> Tween:
	var tween: Tween = create_tween(target, profile)
	tween.tween_property(
		target,
		"position",
		position,
		get_duration(profile),
	)

	return tween


static func fade_scale_to(
	target: Control,
	alpha: float,
	scale: Vector2,
	profile: NucleusUIMotionProfile = null,
	pivot_ratio: Vector2 = Vector2(0.5, 0.5),
) -> Tween:
	set_pivot_ratio(target, pivot_ratio)

	var tween: Tween = create_tween(
		target,
		profile,
	).set_parallel(true)
	var duration: float = get_duration(profile)

	tween.tween_property(
		target,
		"modulate:a",
		clampf(alpha, 0.0, 1.0),
		duration,
	)
	tween.tween_property(
		target,
		"scale",
		scale,
		duration,
	)

	return tween


static func pop(
	target: Control,
	profile: NucleusUIMotionProfile = null,
	from_scale_factor: Vector2 = Vector2(0.92, 0.92),
) -> Tween:
	set_pivot_ratio(target, Vector2(0.5, 0.5))

	var target_scale: Vector2 = target.scale
	var target_alpha: float = target.modulate.a
	var amplitude: float = get_effect_amplitude_scale(profile)
	var effective_factor := Vector2.ONE.lerp(
		from_scale_factor,
		amplitude,
	)

	target.scale = target_scale * effective_factor
	target.modulate.a = 0.0

	return fade_scale_to(
		target,
		target_alpha,
		target_scale,
		profile,
	)


static func punch_scale(
	target: Control,
	multiplier: float = 1.06,
	profile: NucleusUIMotionProfile = null,
) -> Tween:
	set_pivot_ratio(target, Vector2(0.5, 0.5))

	var base_scale: Vector2 = target.scale
	var amplitude: float = get_effect_amplitude_scale(profile)
	var peak_multiplier: float = lerpf(
		1.0,
		maxf(0.0, multiplier),
		amplitude,
	)
	var peak_scale: Vector2 = base_scale * peak_multiplier
	var half_duration: float = get_duration(profile, 0.5)
	var tween: Tween = create_tween(target, profile)

	if is_zero_approx(half_duration):
		tween.tween_property(target, "scale", base_scale, 0.0)
		return tween

	tween.tween_property(
		target,
		"scale",
		peak_scale,
		half_duration,
	)
	tween.tween_property(
		target,
		"scale",
		base_scale,
		half_duration,
	)

	return tween


static func shake(
	target: Control,
	amplitude: Vector2 = Vector2(8.0, 0.0),
	cycles: int = 4,
	profile: NucleusUIMotionProfile = null,
) -> Tween:
	var tween: Tween = create_tween(target, profile)
	var duration: float = get_duration(profile)
	var base_position: Vector2 = target.position
	var safe_cycles: int = maxi(0, cycles)
	var effective_amplitude := (
		amplitude * get_effect_amplitude_scale(profile)
	)

	if (
		safe_cycles == 0
		or is_zero_approx(duration)
		or effective_amplitude.length_squared() <= 0.000001
	):
		tween.tween_property(target, "position", base_position, 0.0)
		return tween

	var segment_duration: float = duration / float(safe_cycles + 1)

	for index: int in range(safe_cycles):
		var decay: float = 1.0 - float(index) / float(safe_cycles)
		var direction: float = -1.0 if index % 2 == 0 else 1.0
		var offset: Vector2 = effective_amplitude * decay * direction

		tween.tween_property(
			target,
			"position",
			base_position + offset,
			segment_duration,
		)

	tween.tween_property(
		target,
		"position",
		base_position,
		segment_duration,
	)

	return tween


static func set_pivot_ratio(
	target: Control,
	ratio: Vector2,
) -> void:
	target.pivot_offset = target.size * Vector2(
		clampf(ratio.x, 0.0, 1.0),
		clampf(ratio.y, 0.0, 1.0),
	)


static func _profile(
	profile: NucleusUIMotionProfile,
) -> NucleusUIMotionProfile:
	return profile if profile else NucleusUIMotionProfile.new()
