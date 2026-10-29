extends "res://tests/headless/test_case.gd"

const DEFAULT_CATALOG := preload(
	"res://addons/nucleus/core/settings/defaults/default_settings_catalog.tres"
)
const OPTIONAL_ENVIRONMENT_DEFINITIONS: Array[Resource] = [
	preload("res://addons/nucleus/core/settings/optional/environment/environment_ssao_enabled.tres"),
	preload("res://addons/nucleus/core/settings/optional/environment/environment_ssil_enabled.tres"),
	preload("res://addons/nucleus/core/settings/optional/environment/environment_glow_enabled.tres"),
	preload(
		"res://addons/nucleus/core/settings/optional/environment/environment_volumetric_fog_enabled.tres"
	),
	preload("res://addons/nucleus/core/settings/optional/environment/environment_sdfgi_enabled.tres"),
	preload("res://addons/nucleus/core/settings/optional/environment/environment_tonemap_mode.tres"),
]


func run() -> Dictionary:
	var catalog: NucleusSettingsCatalog = DEFAULT_CATALOG
	var validation_errors: PackedStringArray = catalog.get_validation_errors()
	expect_true(validation_errors.is_empty(), "Default settings catalog validates")
	expect_equal(catalog.schema_version, 3, "Accessibility expansion bumps settings schema")

	var index := catalog.build_index()
	var required_ids: Array[StringName] = [
		NucleusSettingIds.GRAPHICS_RENDER_SCALE,
		NucleusSettingIds.GRAPHICS_SCALING_3D_MODE,
		NucleusSettingIds.GRAPHICS_SCREEN_SPACE_AA,
		NucleusSettingIds.GRAPHICS_TAA_ENABLED,
		NucleusSettingIds.GRAPHICS_MSAA_2D,
		NucleusSettingIds.GRAPHICS_MSAA_3D,
		NucleusSettingIds.GRAPHICS_DEBANDING_ENABLED,
	]

	for setting_id: StringName in required_ids:
		expect_true(index.has(setting_id), "Default catalog includes %s" % setting_id)

	expect_float(
		index[NucleusSettingIds.GRAPHICS_RENDER_SCALE].get_default_value(),
		1.0,
		"3D render scale defaults to native resolution",
	)
	expect_equal(
		index[NucleusSettingIds.GRAPHICS_SCALING_3D_MODE].get_default_value(),
		Viewport.SCALING_3D_MODE_BILINEAR,
		"3D scaling defaults to bilinear",
	)
	expect_equal(
		index[NucleusSettingIds.GRAPHICS_SCREEN_SPACE_AA].get_default_value(),
		Viewport.SCREEN_SPACE_AA_DISABLED,
		"Screen-space AA is opt-in",
	)

	for resource: Resource in OPTIONAL_ENVIRONMENT_DEFINITIONS:
		var definition := resource as NucleusSettingDefinition
		expect_true(definition != null, "Environment resource is a setting definition")
		if definition == null:
			continue
		expect_true(
			definition.get_validation_errors().is_empty(),
			"Optional Environment definition validates: %s" % definition.get_id(),
		)
		expect_false(
			index.has(definition.get_id()),
			"Environment setting remains opt-in: %s" % definition.get_id(),
		)

	return finish()
