class_name NucleusRenderAudit
extends RefCounted
## Development-time structural audit for common 3D rendering cost patterns.
##
## The audit never mutates scene state. Verify findings with performance sampling
## and Godot's native rendering tools before changing visual quality.


static func inspect(
	root: Node,
	repeated_instance_threshold: int = 8,
	shadow_caster_threshold: int = 64,
	unbounded_visibility_threshold: int = 96,
	shader_material_variant_threshold: int = 8,
	transparent_instance_threshold: int = 24,
) -> Array[NucleusPerformanceDiagnostic]:
	var diagnostics: Array[NucleusPerformanceDiagnostic] = []

	if root == null:
		return diagnostics

	var mesh_groups: Dictionary[String, int] = {}
	var shader_material_groups: Dictionary = {}
	var mesh_instances: int = 0
	var shadow_casters: int = 0
	var unbounded_visibility: int = 0
	var transparent_instances: int = 0

	for node: Node in NucleusNodeUtils.descendants(root, true):
		if not node is MeshInstance3D:
			continue

		var mesh_instance := node as MeshInstance3D

		if mesh_instance.mesh == null:
			continue

		mesh_instances += 1

		var signature := _mesh_signature(mesh_instance)
		mesh_groups[signature] = int(mesh_groups.get(signature, 0)) + 1

		if (
			mesh_instance.cast_shadow
			!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		):
			shadow_casters += 1

		if mesh_instance.visibility_range_end <= 0.0:
			unbounded_visibility += 1

		var active_materials := _active_materials(mesh_instance)

		if (
			mesh_instance.transparency > 0.0
			or _materials_use_transparency(active_materials)
		):
			transparent_instances += 1

		_collect_shader_material_variants(
			active_materials,
			shader_material_groups,
		)

	var largest_group: int = 0

	for count_value: Variant in mesh_groups.values():
		largest_group = maxi(largest_group, int(count_value))

	if largest_group >= maxi(repeated_instance_threshold, 2):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"render_audit_repeated_instances",
				"Repeated mesh instances detected",
				"One mesh/material signature is rendered by many MeshInstance3D nodes.",
				PackedStringArray([
					"Largest repeated group: %d" % largest_group,
					"Audited mesh instances: %d" % mesh_instances,
				]),
				PackedStringArray([
					"Measure draw calls before changing scene structure.",
					"Consider MultiMesh only for presentation that can share draw state.",
					"Keep interactive or independently animated objects as normal nodes.",
				]),
			)
		)

	if shadow_casters >= maxi(shadow_caster_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"render_audit_shadow_casters",
				"Many mesh instances cast shadows",
				"Shadow-capable geometry can multiply depth and lighting work.",
				PackedStringArray([
					"Shadow-casting mesh instances: %d" % shadow_casters,
					"Audited mesh instances: %d" % mesh_instances,
				]),
				PackedStringArray([
					"Inspect shadow cost with the target renderer and lights.",
					"Disable shadows only where they are not visually required.",
				]),
			)
		)

	if unbounded_visibility >= maxi(unbounded_visibility_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"render_audit_unbounded_visibility",
				"Many mesh instances have no visibility range end",
				"Large scenes may benefit from authored visibility ranges or LOD policy.",
				PackedStringArray([
					"Unbounded mesh instances: %d" % unbounded_visibility,
					"Audited mesh instances: %d" % mesh_instances,
				]),
				PackedStringArray([
					"Use native visibility ranges only where distance culling is valid.",
					"Prefer native mesh LOD before introducing custom LOD infrastructure.",
				]),
			)
		)

	var largest_shader_variant_group := 0

	for variants_value: Variant in shader_material_groups.values():
		if typeof(variants_value) != TYPE_DICTIONARY:
			continue

		var variants: Dictionary = variants_value
		largest_shader_variant_group = maxi(
			largest_shader_variant_group,
			variants.size(),
		)

	if (
		largest_shader_variant_group
		>= maxi(shader_material_variant_threshold, 2)
	):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"render_audit_shader_material_variants",
				"Many ShaderMaterial variants share one Shader",
				"Material duplication may reduce shader/material reuse.",
				PackedStringArray([
					"Largest ShaderMaterial variant group: %d"
					% largest_shader_variant_group,
				]),
				PackedStringArray([
					"If variants differ only by scalar/vector values, prefer "
					+ "instance uniforms on GeometryInstance3D.",
					"Keep separate materials when textures, render modes, or "
					+ "shader features genuinely differ.",
				]),
			)
		)

	if transparent_instances >= maxi(transparent_instance_threshold, 1):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"render_audit_transparent_instances",
				"Many mesh instances use transparency",
				"Transparent geometry can increase overdraw and sorting cost.",
				PackedStringArray([
					"Transparent mesh instances: %d" % transparent_instances,
					"Audited mesh instances: %d" % mesh_instances,
				]),
				PackedStringArray([
					"Prefer opaque or alpha-scissor presentation when art allows.",
					"Split small transparent regions from mostly opaque geometry "
					+ "when that reduces transparent coverage.",
				]),
			)
		)

	return diagnostics


static func _mesh_signature(instance: MeshInstance3D) -> String:
	var mesh_key := _resource_key(instance.mesh)
	var material_key := _resource_key(instance.material_override)
	return "%s|%s" % [mesh_key, material_key]


static func _active_materials(
	instance: MeshInstance3D,
) -> Array[Material]:
	var materials: Array[Material] = []

	if instance.material_override != null:
		materials.append(instance.material_override)
		return materials

	for surface_index: int in range(instance.mesh.get_surface_count()):
		var material := instance.get_surface_override_material(
			surface_index
		)

		if material == null:
			material = instance.mesh.surface_get_material(surface_index)

		if material != null and material not in materials:
			materials.append(material)

	return materials


static func _materials_use_transparency(
	materials: Array[Material],
) -> bool:
	for material: Material in materials:
		if (
			material is BaseMaterial3D
			and (material as BaseMaterial3D).transparency
			!= BaseMaterial3D.TRANSPARENCY_DISABLED
		):
			return true

	return false


static func _collect_shader_material_variants(
	materials: Array[Material],
	groups: Dictionary,
) -> void:
	for material: Material in materials:
		if not material is ShaderMaterial:
			continue

		var shader_material := material as ShaderMaterial

		if shader_material.shader == null:
			continue

		var shader_key := _resource_key(shader_material.shader)
		var variants: Dictionary = groups.get(shader_key, {})
		variants[_resource_key(shader_material)] = true
		groups[shader_key] = variants


static func _resource_key(resource: Resource) -> String:
	if resource == null:
		return "none"

	if not resource.resource_path.is_empty():
		return resource.resource_path

	return "instance:%d" % resource.get_instance_id()
