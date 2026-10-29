class_name NucleusTextureAudit
extends RefCounted
## Explicit, non-mutating audit for imported 2D texture resources used in 3D.
##
## Project-directory scanning is development tooling. Use inspect_paths() when
## the caller already owns a narrower list of textures.

const COMPRESS_LOSSLESS: int = 0
const COMPRESS_LOSSY: int = 1
const COMPRESS_VRAM_COMPRESSED: int = 2
const COMPRESS_VRAM_UNCOMPRESSED: int = 3
const COMPRESS_BASIS_UNIVERSAL: int = 4

const NORMAL_MAP_DETECT: int = 0
const NORMAL_MAP_ENABLE: int = 1
const NORMAL_MAP_DISABLED: int = 2

static var TEXTURE_EXTENSIONS := PackedStringArray([
	"bmp",
	"dds",
	"exr",
	"hdr",
	"jpeg",
	"jpg",
	"png",
	"svg",
	"tga",
	"webp",
])


static func inspect_directory(
	root_path: String = "res://",
	profile: NucleusTextureBudgetProfile = null,
	assume_3d: bool = true,
) -> Array[NucleusPerformanceDiagnostic]:
	var paths := PackedStringArray()
	_collect_texture_paths(root_path, paths)
	return inspect_paths(paths, profile, assume_3d)


static func inspect_paths(
	paths: PackedStringArray,
	profile: NucleusTextureBudgetProfile = null,
	assume_3d: bool = true,
) -> Array[NucleusPerformanceDiagnostic]:
	var resolved_profile := profile

	if resolved_profile == null:
		resolved_profile = NucleusTextureBudgetProfile.new()

	var diagnostics: Array[NucleusPerformanceDiagnostic] = []

	for source_path: String in paths:
		if not ResourceLoader.exists(source_path):
			continue

		var resource := ResourceLoader.load(source_path)

		if not resource is Texture2D:
			continue

		var texture := resource as Texture2D
		var params := _load_import_params(source_path)
		diagnostics.append_array(
			inspect_import_settings(
				source_path,
				texture.get_width(),
				texture.get_height(),
				params,
				resolved_profile,
				assume_3d,
			)
		)

	return diagnostics


static func inspect_import_settings(
	source_path: String,
	width: int,
	height: int,
	params: Dictionary,
	profile: NucleusTextureBudgetProfile,
	assume_3d: bool = true,
) -> Array[NucleusPerformanceDiagnostic]:
	var diagnostics: Array[NucleusPerformanceDiagnostic] = []

	if profile == null:
		profile = NucleusTextureBudgetProfile.new()

	var largest_dimension := maxi(width, height)
	var mipmaps: bool = bool(params.get("mipmaps/generate", false))
	var compression_mode := int(
		params.get("compress/mode", COMPRESS_LOSSLESS)
	)

	if largest_dimension >= profile.critical_dimension:
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.WARNING,
				&"texture_audit_critical_dimensions",
				"Very large texture detected",
				"Large textures can increase VRAM pressure and bandwidth cost.",
				PackedStringArray([
					source_path,
					"Dimensions: %dx%d" % [width, height],
					"RGBA8 baseline estimate: %s"
					% _format_bytes(
						estimate_rgba8_bytes(width, height, mipmaps)
					),
				]),
				PackedStringArray([
					"Verify the texture needs this texel density in gameplay.",
					"Prefer import size limits or authored lower-resolution assets "
					+ "when visual quality allows.",
				]),
			)
		)
	elif largest_dimension >= profile.warning_dimension:
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"texture_audit_large_dimensions",
				"Large texture should be reviewed",
				"Texture dimensions exceed the configured review threshold.",
				PackedStringArray([
					source_path,
					"Dimensions: %dx%d" % [width, height],
				]),
				PackedStringArray([
					"Check real on-screen texel density before reducing quality.",
				]),
			)
		)

	if assume_3d and profile.warn_missing_mipmaps and not mipmaps:
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.WARNING,
				&"texture_audit_missing_mipmaps_3d",
				"3D texture has no mipmaps",
				"Missing mipmaps can increase distant sampling cost and aliasing.",
				PackedStringArray([source_path]),
				PackedStringArray([
					"Enable mipmaps unless this texture has a deliberate exception.",
				]),
			)
		)

	if (
		assume_3d
		and profile.warn_non_vram_compression
		and compression_mode not in [
			COMPRESS_VRAM_COMPRESSED,
			COMPRESS_BASIS_UNIVERSAL,
		]
	):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"texture_audit_non_vram_compressed_3d",
				"3D texture uses a high-memory compression mode",
				"Review whether this texture should use a GPU-friendly import mode.",
				PackedStringArray([
					source_path,
					"Compression mode: %s"
					% compression_mode_name(compression_mode),
				]),
				PackedStringArray([
					"Prefer VRAM Compressed or Basis Universal for ordinary 3D "
					+ "textures when their quality tradeoff is acceptable.",
					"Keep deliberate lossless/uncompressed exceptions documented.",
				]),
			)
		)

	var normal_mode := int(
		params.get("compress/normal_map", NORMAL_MAP_DETECT)
	)

	if (
		assume_3d
		and profile.warn_disabled_normal_map_detection
		and normal_mode == NORMAL_MAP_DISABLED
		and _looks_like_normal_map(source_path, profile.normal_map_tokens)
	):
		diagnostics.append(
			NucleusPerformanceDiagnostic.build(
				NucleusPerformanceDiagnostic.Severity.INFO,
				&"texture_audit_normal_map_detection_disabled",
				"Possible normal map has normal-map compression disabled",
				"Filename heuristics suggest this asset may contain tangent normals.",
				PackedStringArray([source_path]),
				PackedStringArray([
					"Verify import intent. Godot can use RGTC-style normal-map "
					+ "compression for detected normal maps.",
				]),
			)
		)

	return diagnostics


static func estimate_rgba8_bytes(
	width: int,
	height: int,
	with_mipmaps: bool,
) -> int:
	var base := maxi(width, 0) * maxi(height, 0) * 4

	if not with_mipmaps:
		return base

	return int(ceil(float(base) * 4.0 / 3.0))


static func compression_mode_name(mode: int) -> String:
	match mode:
		COMPRESS_LOSSY:
			return "Lossy"
		COMPRESS_VRAM_COMPRESSED:
			return "VRAM Compressed"
		COMPRESS_VRAM_UNCOMPRESSED:
			return "VRAM Uncompressed"
		COMPRESS_BASIS_UNIVERSAL:
			return "Basis Universal"
		_:
			return "Lossless"


static func _load_import_params(source_path: String) -> Dictionary:
	var import_path := source_path + ".import"

	if not FileAccess.file_exists(import_path):
		return {}

	var config := ConfigFile.new()

	if config.load(import_path) != OK:
		return {}

	var params: Dictionary = {}

	for key: String in config.get_section_keys("params"):
		params[key] = config.get_value("params", key)

	return params


static func _looks_like_normal_map(
	source_path: String,
	tokens: PackedStringArray,
) -> bool:
	var lower := source_path.to_lower()

	for token: String in tokens:
		if not token.is_empty() and lower.contains(token.to_lower()):
			return true

	return false


static func _collect_texture_paths(
	root_path: String,
	output: PackedStringArray,
) -> void:
	var directory := DirAccess.open(root_path)

	if directory == null:
		return

	directory.list_dir_begin()

	while true:
		var entry := directory.get_next()

		if entry.is_empty():
			break

		if entry.begins_with("."):
			continue

		var path := root_path.path_join(entry)

		if directory.current_is_dir():
			_collect_texture_paths(path, output)
			continue

		if path.get_extension().to_lower() in TEXTURE_EXTENSIONS:
			output.append(path)

	directory.list_dir_end()


static func _format_bytes(byte_count: int) -> String:
	var value := float(maxi(byte_count, 0))

	if value >= 1024.0 * 1024.0:
		return "%.2f MiB" % (value / (1024.0 * 1024.0))

	if value >= 1024.0:
		return "%.2f KiB" % (value / 1024.0)

	return "%d B" % byte_count
