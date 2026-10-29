class_name NucleusTextureSetAudit
extends RefCounted
## Non-destructive filename-level audit for common PBR texture-set redundancy.
##
## This audit never deletes, reimports, or assumes that every vendor map belongs
## in the runtime material. It only highlights sets that deserve review.

const TYPE_ALBEDO: StringName = &"albedo"
const TYPE_NORMAL_GL: StringName = &"normal_gl"
const TYPE_NORMAL_DX: StringName = &"normal_dx"
const TYPE_NORMAL: StringName = &"normal"
const TYPE_ROUGHNESS: StringName = &"roughness"
const TYPE_AO: StringName = &"ao"
const TYPE_ARM: StringName = &"arm"
const TYPE_ORM: StringName = &"orm"
const TYPE_DISPLACEMENT: StringName = &"displacement"
const TYPE_HEIGHT: StringName = &"height"

const SUFFIXES: Array[Dictionary] = [
	{"suffix": "_normalgl", "type": TYPE_NORMAL_GL},
	{"suffix": "_normal_gl", "type": TYPE_NORMAL_GL},
	{"suffix": "_normaldx", "type": TYPE_NORMAL_DX},
	{"suffix": "_normal_dx", "type": TYPE_NORMAL_DX},
	{"suffix": "_roughness", "type": TYPE_ROUGHNESS},
	{"suffix": "_rough", "type": TYPE_ROUGHNESS},
	{"suffix": "_displacement", "type": TYPE_DISPLACEMENT},
	{"suffix": "_basecolor", "type": TYPE_ALBEDO},
	{"suffix": "_base_color", "type": TYPE_ALBEDO},
	{"suffix": "_albedo", "type": TYPE_ALBEDO},
	{"suffix": "_normal", "type": TYPE_NORMAL},
	{"suffix": "_color", "type": TYPE_ALBEDO},
	{"suffix": "_height", "type": TYPE_HEIGHT},
	{"suffix": "_ambientocclusion", "type": TYPE_AO},
	{"suffix": "_ambient_occlusion", "type": TYPE_AO},
	{"suffix": "_occlusion", "type": TYPE_AO},
	{"suffix": "_arm", "type": TYPE_ARM},
	{"suffix": "_orm", "type": TYPE_ORM},
	{"suffix": "_ao", "type": TYPE_AO},
]


static func inspect_paths(
	paths: PackedStringArray,
) -> Array[NucleusPerformanceDiagnostic]:
	var sets := _group_paths(paths)
	var diagnostics: Array[NucleusPerformanceDiagnostic] = []

	for set_key_value: Variant in sets.keys():
		var set_key := String(set_key_value)
		var texture_set: Dictionary = sets[set_key]
		var packed_present := (
			texture_set.has(TYPE_ARM)
			or texture_set.has(TYPE_ORM)
		)

		if (
			texture_set.has(TYPE_NORMAL_GL)
			and texture_set.has(TYPE_NORMAL_DX)
		):
			diagnostics.append(
				_build_diagnostic(
					&"texture_set_dual_normal_convention",
					"Texture set contains both OpenGL and DirectX normals",
					"Verify which normal convention the project actually consumes.",
					set_key,
					texture_set,
					PackedStringArray([
						"Prefer the convention expected by the Godot import pipeline.",
						"Keep the alternate source only when the asset pipeline needs it.",
					]),
				)
			)

		if packed_present and texture_set.has(TYPE_ROUGHNESS):
			diagnostics.append(
				_build_diagnostic(
					&"texture_set_packed_roughness_overlap",
					"Packed material map overlaps a standalone roughness map",
					"ARM/ORM commonly already contains a roughness channel.",
					set_key,
					texture_set,
					PackedStringArray([
						"Choose the runtime representation deliberately.",
						"Do not sample both representations without a material reason.",
					]),
				)
			)

		if packed_present and texture_set.has(TYPE_AO):
			diagnostics.append(
				_build_diagnostic(
					&"texture_set_packed_ao_overlap",
					"Packed material map overlaps a standalone AO map",
					"ARM/ORM commonly already contains an occlusion channel.",
					set_key,
					texture_set,
					PackedStringArray([
						"Keep standalone AO only when a consumer needs it separately.",
					]),
				)
			)

		if (
			texture_set.has(TYPE_DISPLACEMENT)
			or texture_set.has(TYPE_HEIGHT)
		):
			diagnostics.append(
				_build_diagnostic(
					&"texture_set_height_detail_review",
					"Texture set includes displacement or height detail",
					"Height/displacement maps are optional runtime inputs, not free detail.",
					set_key,
					texture_set,
					PackedStringArray([
						"Verify an actual shader/material consumer before paying for it.",
						"Do not enable parallax/displacement only because the vendor "
						+ "package contains the map.",
					]),
				)
			)

	return diagnostics


static func classify_path(path: String) -> Dictionary:
	var file_name := path.get_file().get_basename().to_lower()
	file_name = file_name.replace("-", "_")
	file_name = file_name.replace(" ", "_")

	while file_name.contains("__"):
		file_name = file_name.replace("__", "_")

	var resolution_suffix := _take_resolution_suffix(file_name)

	if not resolution_suffix.is_empty():
		file_name = file_name.left(
			file_name.length() - resolution_suffix.length()
		)

	for entry: Dictionary in SUFFIXES:
		var suffix := String(entry["suffix"])

		if not file_name.ends_with(suffix):
			continue

		var set_key := file_name.left(
			file_name.length() - suffix.length()
		)
		set_key += resolution_suffix
		return {
			"set_key": set_key,
			"type": StringName(entry["type"]),
		}

	return {
		"set_key": file_name + resolution_suffix,
		"type": &"",
	}


static func _take_resolution_suffix(file_name: String) -> String:
	for suffix: String in [
		"_512",
		"_1k",
		"_2k",
		"_4k",
		"_8k",
		"_16k",
		"_1024",
		"_2048",
		"_4096",
		"_8192",
	]:
		if file_name.ends_with(suffix):
			return suffix

	return ""


static func _group_paths(
	paths: PackedStringArray,
) -> Dictionary:
	var sets: Dictionary = {}

	for path: String in paths:
		var classification := classify_path(path)
		var texture_type := StringName(classification["type"])

		if texture_type == &"":
			continue

		var set_key := String(classification["set_key"])
		var texture_set: Dictionary = sets.get(set_key, {})
		var typed_paths: PackedStringArray = texture_set.get(
			texture_type,
			PackedStringArray(),
		)
		typed_paths.append(path)
		texture_set[texture_type] = typed_paths
		sets[set_key] = texture_set

	return sets


static func _build_diagnostic(
	code: StringName,
	title: String,
	summary: String,
	set_key: String,
	texture_set: Dictionary,
	recommendations: PackedStringArray,
) -> NucleusPerformanceDiagnostic:
	var details := PackedStringArray([
		"Texture set: %s" % set_key,
	])

	for texture_type_value: Variant in texture_set.keys():
		var texture_type := StringName(texture_type_value)
		var typed_paths: PackedStringArray = texture_set[texture_type]

		for path: String in typed_paths:
			details.append("%s: %s" % [texture_type, path])

	return NucleusPerformanceDiagnostic.build(
		NucleusPerformanceDiagnostic.Severity.INFO,
		code,
		title,
		summary,
		details,
		recommendations,
	)
