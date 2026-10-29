class_name NucleusLightingAudit3D
extends RefCounted
## Development-time structural audit for native Godot 3D lighting/shadows.
##
## The audit never mutates scene state. Findings are review prompts that must be
## verified with representative scenes, the active renderer, and target hardware.


static func inspect(
	root: Node,
	viewport: Viewport = null,
	shadowed_local_threshold: int = 8,
	no_distance_fade_threshold: int = 8,
	omni_cube_shadow_threshold: int = 4,
	area_light_threshold: int = 2,
	soft_shadow_threshold: int = 6,
	projector_threshold: int = 8,
	directional_shadow_distance_threshold: float = 150.0,
) -> Array[NucleusPerformanceDiagnostic]:
	var diagnostics: Array[NucleusPerformanceDiagnostic] = []

	if root == null:
		return diagnostics

	var snapshot_data: Dictionary = snapshot(
		root,
		viewport,
		directional_shadow_distance_threshold,
	)
	var shadowed_local: int = int(
		snapshot_data.get("shadowed_local_lights", 0)
	)
	var positional_shadow_lights: int = int(
		snapshot_data.get("positional_shadow_lights", 0)
	)
	var no_distance_fade: int = int(
		snapshot_data.get("local_lights_without_distance_fade", 0)
	)
	var late_shadow_cutoff: int = int(
		snapshot_data.get("late_local_shadow_cutoff", 0)
	)
	var cube_shadows: int = int(
		snapshot_data.get("omni_cube_shadows", 0)
	)
	var area_lights: int = int(
		snapshot_data.get("area_lights", 0)
	)
	var area_shadow_lights: int = int(
		snapshot_data.get("area_shadow_lights", 0)
	)
	var soft_shadow_lights: int = int(
		snapshot_data.get("soft_shadow_lights", 0)
	)
	var projectors: int = int(
		snapshot_data.get("projector_lights", 0)
	)
	var directional_four_split: int = int(
		snapshot_data.get("directional_four_split_shadows", 0)
	)
	var directional_long_range: int = int(
		snapshot_data.get("directional_long_range_shadows", 0)
	)
	var directional_pcss: int = int(
		snapshot_data.get("directional_pcss_shadows", 0)
	)
	var directional_blended: int = int(
		snapshot_data.get("directional_blended_splits", 0)
	)
	var renderer: String = str(
		snapshot_data.get("rendering_method", "")
	)

	if shadowed_local >= maxi(shadowed_local_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_shadowed_local_lights",
				"Many local lights request real-time shadows",
				"Omni/Spot/Area shadow maps can multiply scene rendering work.",
				PackedStringArray([
					"Shadowed local lights: %d" % shadowed_local,
					"Rendering method: %s" % renderer,
				]),
				PackedStringArray([
					"Keep shadows only where they materially improve readability.",
					"Prefer distance_fade_shadow below the light fade end.",
					"Use viewport shadow-atlas quality tiers for product presets.",
				]),
			)
		)

	if no_distance_fade >= maxi(no_distance_fade_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_local_lights_without_distance_fade",
				"Many local lights have no native distance fade",
				"Omni/Spot lights can remain active farther from the camera than needed.",
				PackedStringArray([
					"Local lights without distance fade: %d"
					% no_distance_fade,
				]),
				PackedStringArray([
					"Author native Light3D distance fade where distant removal is valid.",
					"Let NucleusLightQualityController3D scale authored fade distances.",
				]),
			)
		)

	if late_shadow_cutoff > 0:
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_late_shadow_cutoff",
				"Local shadows persist until the light fade ends",
				"Shadow rendering is often more expensive than lighting alone.",
				PackedStringArray([
					"Lights with late shadow cutoff: %d"
					% late_shadow_cutoff,
				]),
				PackedStringArray([
					"Set distance_fade_shadow below fade begin + fade length.",
					"Verify the shorter shadow range against camera movement.",
				]),
			)
		)

	if cube_shadows >= maxi(omni_cube_shadow_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_omni_cube_shadows",
				"Several OmniLight3D nodes use cubemap shadows",
				"Cubemap omni shadows are higher quality but slower than dual paraboloid.",
				PackedStringArray([
					"Shadowed cube OmniLight3D nodes: %d" % cube_shadows,
				]),
				PackedStringArray([
					"Keep cubemap shadows for lights where the quality difference matters.",
					"Use dual paraboloid in reduced/minimal quality when acceptable.",
				]),
			)
		)

	if area_lights >= maxi(area_light_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.WARNING,
				&"lighting_audit_area_light_pressure",
				"AreaLight3D usage deserves explicit GPU review",
				"Area lights are a higher-cost lighting primitive.",
				PackedStringArray([
					"AreaLight3D nodes: %d" % area_lights,
					"Shadowed AreaLight3D nodes: %d"
					% area_shadow_lights,
					"Rendering method: %s" % renderer,
				]),
				PackedStringArray([
					"Profile AreaLight3D on the lowest supported GPU.",
					"Prefer Omni/Spot approximations when visual quality remains acceptable.",
				]),
			)
		)

	if soft_shadow_lights >= maxi(soft_shadow_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_soft_shadow_pressure",
				"Many shadowed lights request soft-shadow work",
				"Light size/angular distance can increase shadow filtering cost.",
				PackedStringArray([
					"Soft-shadow lights: %d" % soft_shadow_lights,
				]),
				PackedStringArray([
					"Reduce light size/angular distance in lower quality tiers.",
					"Retain soft shadows on hero lights where they are visible.",
				]),
			)
		)

	if projectors >= maxi(projector_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_projector_pressure",
				"Many local lights use projector textures",
				"Projectors add texture sampling and are renderer-dependent.",
				PackedStringArray([
					"Projector lights: %d" % projectors,
					"Rendering method: %s" % renderer,
				]),
				PackedStringArray([
					"Disable decorative projectors in lower quality tiers if needed.",
					"Do not rely on projectors in Compatibility rendering.",
				]),
			)
		)

	if (
		directional_four_split > 0
		or directional_long_range > 0
		or directional_pcss > 0
		or directional_blended > 0
	):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"lighting_audit_directional_shadow_quality",
				"Directional shadows use high-quality features",
				"Directional shadow splits, range and softness should match the preset.",
				PackedStringArray([
					"4-split lights: %d" % directional_four_split,
					"Long-range lights: %d" % directional_long_range,
					"Directional PCSS lights: %d" % directional_pcss,
					"Blended split lights: %d" % directional_blended,
					"Long-range threshold: %.1f"
					% directional_shadow_distance_threshold,
				]),
				PackedStringArray([
					"Use 2 splits or orthogonal shadows on lower tiers.",
					"Shorten directional_shadow_max_distance before reducing gameplay.",
					"Disable expensive softness where the visual difference is small.",
				]),
			)
		)

	_append_renderer_compatibility_diagnostics(
		diagnostics,
		renderer,
		projectors,
		area_shadow_lights,
		directional_pcss,
	)

	var atlas_size: int = int(
		snapshot_data.get("positional_shadow_atlas_size", -1)
	)

	if positional_shadow_lights > 0 and atlas_size == 0:
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.WARNING,
				&"lighting_audit_positional_shadow_atlas_disabled",
				"Local lights request shadows but the positional atlas is disabled",
				"Omni/Spot shadows cannot render while the Viewport atlas size is zero.",
				PackedStringArray([
					"Omni/Spot shadow lights: %d"
					% positional_shadow_lights,
				]),
				PackedStringArray([
					"Enable the atlas for presets that require positional shadows.",
					"Or disable local shadow requests intentionally for that preset.",
				]),
			)
		)

	return diagnostics


static func snapshot(
	root: Node,
	viewport: Viewport = null,
	directional_shadow_distance_threshold: float = 150.0,
) -> Dictionary:
	var result: Dictionary = {
		"rendering_method": _rendering_method(),
		"lights": 0,
		"directional_lights": 0,
		"omni_lights": 0,
		"spot_lights": 0,
		"area_lights": 0,
		"shadowed_local_lights": 0,
		"positional_shadow_lights": 0,
		"area_shadow_lights": 0,
		"local_lights_without_distance_fade": 0,
		"late_local_shadow_cutoff": 0,
		"omni_cube_shadows": 0,
		"soft_shadow_lights": 0,
		"projector_lights": 0,
		"directional_four_split_shadows": 0,
		"directional_long_range_shadows": 0,
		"directional_pcss_shadows": 0,
		"directional_blended_splits": 0,
		"positional_shadow_atlas_size": -1,
	}

	if root == null:
		return result

	for node: Node in NucleusNodeUtils.descendants(root, true):
		if not node is Light3D:
			continue

		var light: Light3D = node as Light3D

		if not light.visible:
			continue

		result["lights"] = int(result["lights"]) + 1

		if light.shadow_enabled and _uses_soft_shadows(light):
			result["soft_shadow_lights"] = (
				int(result["soft_shadow_lights"]) + 1
			)

		if light is DirectionalLight3D:
			_scan_directional_light(
				light as DirectionalLight3D,
				result,
				directional_shadow_distance_threshold,
			)
			continue

		if light is OmniLight3D:
			_scan_omni_light(light as OmniLight3D, result)
		elif light is SpotLight3D:
			_scan_spot_light(light as SpotLight3D, result)
		elif light is AreaLight3D:
			_scan_area_light(light as AreaLight3D, result)

	if viewport != null:
		result["positional_shadow_atlas_size"] = (
			viewport.positional_shadow_atlas_size
		)

	return result


static func _scan_local_light(
	light: Light3D,
	result: Dictionary,
) -> void:
	if light.shadow_enabled:
		result["shadowed_local_lights"] = (
			int(result["shadowed_local_lights"]) + 1
		)
		result["positional_shadow_lights"] = (
			int(result["positional_shadow_lights"]) + 1
		)

	if not light.distance_fade_enabled:
		result["local_lights_without_distance_fade"] = (
			int(result["local_lights_without_distance_fade"]) + 1
		)
	elif (
		light.shadow_enabled
		and light.distance_fade_shadow
		>= light.distance_fade_begin + light.distance_fade_length
	):
		result["late_local_shadow_cutoff"] = (
			int(result["late_local_shadow_cutoff"]) + 1
		)

	if light.light_projector != null:
		result["projector_lights"] = (
			int(result["projector_lights"]) + 1
		)


static func _scan_omni_light(
	light: OmniLight3D,
	result: Dictionary,
) -> void:
	result["omni_lights"] = int(result["omni_lights"]) + 1
	_scan_local_light(light, result)

	if (
		light.shadow_enabled
		and light.omni_shadow_mode == OmniLight3D.SHADOW_CUBE
	):
		result["omni_cube_shadows"] = (
			int(result["omni_cube_shadows"]) + 1
		)


static func _scan_spot_light(
	light: SpotLight3D,
	result: Dictionary,
) -> void:
	result["spot_lights"] = int(result["spot_lights"]) + 1
	_scan_local_light(light, result)


static func _scan_area_light(
	light: AreaLight3D,
	result: Dictionary,
) -> void:
	result["area_lights"] = int(result["area_lights"]) + 1

	if light.shadow_enabled:
		result["shadowed_local_lights"] = (
			int(result["shadowed_local_lights"]) + 1
		)
		result["area_shadow_lights"] = (
			int(result["area_shadow_lights"]) + 1
		)


static func _scan_directional_light(
	light: DirectionalLight3D,
	result: Dictionary,
	long_distance_threshold: float,
) -> void:
	result["directional_lights"] = (
		int(result["directional_lights"]) + 1
	)

	if not light.shadow_enabled:
		return

	if (
		light.directional_shadow_mode
		== DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	):
		result["directional_four_split_shadows"] = (
			int(result["directional_four_split_shadows"]) + 1
		)

	if (
		light.directional_shadow_max_distance
		>= maxf(long_distance_threshold, 0.0)
	):
		result["directional_long_range_shadows"] = (
			int(result["directional_long_range_shadows"]) + 1
		)

	if light.light_angular_distance > 0.0:
		result["directional_pcss_shadows"] = (
			int(result["directional_pcss_shadows"]) + 1
		)

	if light.directional_shadow_blend_splits:
		result["directional_blended_splits"] = (
			int(result["directional_blended_splits"]) + 1
		)


static func _uses_soft_shadows(light: Light3D) -> bool:
	if light is DirectionalLight3D:
		return light.light_angular_distance > 0.0

	return light.light_size > 0.0


static func _rendering_method() -> String:
	var rendering_method: String = (
		RenderingServer.get_current_rendering_method()
	)

	if not rendering_method.is_empty():
		return rendering_method

	var configured: Variant = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method",
		"",
	)
	return str(configured)


static func _append_renderer_compatibility_diagnostics(
	diagnostics: Array[NucleusPerformanceDiagnostic],
	renderer: String,
	projectors: int,
	area_shadow_lights: int,
	directional_pcss: int,
) -> void:
	var evidence: PackedStringArray = PackedStringArray()
	var suggestions: PackedStringArray = PackedStringArray()

	if renderer == "gl_compatibility":
		if projectors > 0:
			evidence.append(
				"Projector lights configured: %d" % projectors
			)
			suggestions.append(
				"Compatibility does not support Light3D projector textures."
			)

		if area_shadow_lights > 0:
			evidence.append(
				"Shadowed AreaLight3D nodes: %d"
				% area_shadow_lights
			)
			suggestions.append(
				"Compatibility does not support AreaLight3D shadows."
			)

	if renderer in ["mobile", "gl_compatibility"]:
		if directional_pcss > 0:
			evidence.append(
				"Directional PCSS lights configured: %d"
				% directional_pcss
			)
			suggestions.append(
				"Directional PCSS is only supported in Forward+."
			)

	if evidence.is_empty():
		return

	diagnostics.append(
		NucleusPerformanceDiagnostic.build(
			NucleusPerformanceDiagnostic.Severity.WARNING,
			&"lighting_audit_renderer_feature_mismatch",
			"Lighting features do not match the active renderer",
			"Some authored light features are unsupported by this rendering method.",
			evidence,
			suggestions,
		)
	)
