class_name NucleusDisplaySettingsApplier
extends Node
## Applies built-in display and root-viewport settings to Godot runtime APIs.

signal temporary_render_scale_revoked(reason: StringName)

const LOG_CONTEXT: StringName = &"DisplaySettings"
const EMBEDDED_WINDOW_WARNING: String = (
	"Window changes are unavailable while Godot game embedding is enabled. "
	+ "Disable 'Embed Game on Next Play' to validate this setting."
)

var _settings: NucleusSettingsService
var _temporary_owner: WeakRef
var _temporary_render_scale: float = -1.0


func _ready() -> void:
	if not ProjectSettings.get_setting("nucleus/integration/manage_project_preferences", false):
		return
	_settings = get_parent() as NucleusSettingsService

	if _settings == null:
		NucleusLog.error(
			"Display settings applier requires NucleusSettingsService as parent.",
			LOG_CONTEXT,
		)
		return

	_settings.setting_changed.connect(_on_setting_changed)
	_settings.settings_loaded.connect(_apply_all)

	if _settings.is_initialized():
		_apply_all()


func _apply_all() -> void:
	# A Settings reload always returns authority to the authored values.
	if _temporary_owner != null:
		_temporary_owner = null
		_temporary_render_scale = -1.0
		temporary_render_scale_revoked.emit(&"settings_reloaded")
	_apply_window_mode(
		_settings.get_int(
			NucleusSettingIds.DISPLAY_WINDOW_MODE,
			DisplayServer.WINDOW_MODE_WINDOWED,
		)
	)
	_apply_borderless(_settings.get_bool(NucleusSettingIds.DISPLAY_BORDERLESS))
	_apply_vsync(
		_settings.get_int(
			NucleusSettingIds.DISPLAY_VSYNC_MODE,
			DisplayServer.VSYNC_ENABLED,
		)
	)
	_apply_max_fps(_settings.get_int(NucleusSettingIds.GRAPHICS_MAX_FPS))
	_apply_scaling_3d_mode(
		_settings.get_int(
			NucleusSettingIds.GRAPHICS_SCALING_3D_MODE,
			Viewport.SCALING_3D_MODE_BILINEAR,
		)
	)
	_apply_render_scale(
		_settings.get_float(NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0)
	)
	_apply_screen_space_aa(
		_settings.get_int(
			NucleusSettingIds.GRAPHICS_SCREEN_SPACE_AA,
			Viewport.SCREEN_SPACE_AA_DISABLED,
		)
	)
	_apply_taa(_settings.get_bool(NucleusSettingIds.GRAPHICS_TAA_ENABLED))
	_apply_msaa_2d(
		_settings.get_int(
			NucleusSettingIds.GRAPHICS_MSAA_2D,
			Viewport.MSAA_DISABLED,
		)
	)
	_apply_msaa_3d(
		_settings.get_int(
			NucleusSettingIds.GRAPHICS_MSAA_3D,
			Viewport.MSAA_DISABLED,
		)
	)
	_apply_debanding(
		_settings.get_bool(NucleusSettingIds.GRAPHICS_DEBANDING_ENABLED)
	)


func _on_setting_changed(
	setting_id: StringName,
	value: Variant,
	_previous_value: Variant,
) -> void:
	match setting_id:
		NucleusSettingIds.DISPLAY_WINDOW_MODE:
			_apply_window_mode(value)
		NucleusSettingIds.DISPLAY_BORDERLESS:
			_apply_borderless(value)
		NucleusSettingIds.DISPLAY_VSYNC_MODE:
			_apply_vsync(value)
		NucleusSettingIds.GRAPHICS_MAX_FPS:
			_apply_max_fps(value)
		NucleusSettingIds.GRAPHICS_SCALING_3D_MODE:
			_apply_scaling_3d_mode(value)
		NucleusSettingIds.GRAPHICS_RENDER_SCALE:
			if _temporary_owner != null:
				_temporary_owner = null
				_temporary_render_scale = -1.0
				_apply_render_scale(value)
				temporary_render_scale_revoked.emit(&"user_setting_changed")
			else:
				_apply_render_scale(value)
		NucleusSettingIds.GRAPHICS_SCREEN_SPACE_AA:
			_apply_screen_space_aa(value)
		NucleusSettingIds.GRAPHICS_TAA_ENABLED:
			_apply_taa(value)
		NucleusSettingIds.GRAPHICS_MSAA_2D:
			_apply_msaa_2d(value)
		NucleusSettingIds.GRAPHICS_MSAA_3D:
			_apply_msaa_3d(value)
		NucleusSettingIds.GRAPHICS_DEBANDING_ENABLED:
			_apply_debanding(value)


@warning_ignore("int_as_enum_without_cast")
func _apply_window_mode(value: int) -> void:
	if NucleusPlatform.uses_managed_window_mode():
		return
	if DisplayServer.window_get_mode() == value:
		return
	if Engine.is_embedded_in_editor():
		NucleusLog.warning(EMBEDDED_WINDOW_WARNING, LOG_CONTEXT)
		return
	DisplayServer.window_set_mode(value)


func _apply_borderless(value: bool) -> void:
	if NucleusPlatform.uses_managed_window_mode():
		return
	if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) == value:
		return
	if Engine.is_embedded_in_editor():
		NucleusLog.warning(EMBEDDED_WINDOW_WARNING, LOG_CONTEXT)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, value)


@warning_ignore("int_as_enum_without_cast")
func _apply_vsync(value: int) -> void:
	DisplayServer.window_set_vsync_mode(value)


func _apply_max_fps(value: int) -> void:
	Engine.max_fps = maxi(0, value)


## Only this existing Settings applier may write the root viewport scale.
## A temporary requester is scene-owned and cannot persist a preference.
func request_temporary_render_scale(requester: Node, value: float) -> Error:
	if not is_instance_valid(requester) or not requester.is_inside_tree():
		return ERR_INVALID_PARAMETER
	if not is_finite(value) or value < 0.25 or value > 1.0:
		return ERR_INVALID_PARAMETER
	if _settings == null or not _settings.is_initialized():
		return ERR_UNCONFIGURED
	var current: Node = _current_temporary_owner()
	if current != null and current != requester:
		return ERR_BUSY
	_temporary_owner = weakref(requester)
	_temporary_render_scale = value
	_apply_render_scale(_settings.get_float(NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0))
	return OK


func release_temporary_render_scale(requester: Node) -> Error:
	var current: Node = _current_temporary_owner()
	if current == null:
		return OK
	if current != requester:
		return ERR_BUSY
	_temporary_owner = null
	_temporary_render_scale = -1.0
	if _settings != null and _settings.is_initialized():
		_apply_render_scale(
			_settings.get_float(NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0)
		)
	return OK


func get_effective_render_scale() -> float:
	if _settings == null or not _settings.is_initialized():
		return 1.0
	var authored: float = _settings.get_float(
		NucleusSettingIds.GRAPHICS_RENDER_SCALE, 1.0
	)
	return minf(authored, _temporary_render_scale) if (
		_current_temporary_owner() != null
	) else authored


func get_temporary_render_scale() -> float:
	return _temporary_render_scale if _current_temporary_owner() != null else -1.0


func _current_temporary_owner() -> Node:
	if _temporary_owner == null:
		return null
	var requester: Node = _temporary_owner.get_ref() as Node
	if not is_instance_valid(requester) or not requester.is_inside_tree():
		_temporary_owner = null
		_temporary_render_scale = -1.0
		return null
	return requester


func _apply_render_scale(value: float) -> void:
	var scale: float = value
	if _current_temporary_owner() != null:
		scale = minf(value, _temporary_render_scale)
	get_tree().root.scaling_3d_scale = clampf(scale, 0.25, 2.0)



func _apply_scaling_3d_mode(value: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	get_tree().root.scaling_3d_mode = value



func _apply_screen_space_aa(value: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	get_tree().root.screen_space_aa = value


func _apply_taa(value: bool) -> void:
	get_tree().root.use_taa = value



func _apply_msaa_2d(value: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	get_tree().root.msaa_2d = value


func _apply_msaa_3d(value: int) -> void:
	@warning_ignore("int_as_enum_without_cast")
	get_tree().root.msaa_3d = value


func _apply_debanding(value: bool) -> void:
	get_tree().root.use_debanding = value
