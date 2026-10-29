class_name NucleusUIScreenEffects
extends CanvasLayer
## Scene-owned full-screen fade and flash effects.
##
## Add this component to a persistent UI shell when effects must survive scene
## replacement. It is not an Autoload by default.

signal covered
signal revealed
signal flash_started
signal flash_finished

@export var fade_motion: NucleusUIMotionProfile
@export var flash_motion: NucleusUIMotionProfile

var _fade_rect: ColorRect
var _fade_tween: Tween


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if fade_motion == null:
		fade_motion = NucleusUIMotionProfile.new()
		fade_motion.duration = 0.25

	if flash_motion == null:
		flash_motion = NucleusUIMotionProfile.new()
		flash_motion.duration = 0.16

	_fade_rect = _create_overlay()
	_fade_rect.hide()
	_fade_rect.modulate.a = 0.0


func fade_to(
	color: Color = Color.BLACK,
) -> Tween:
	_kill_fade_tween()

	_fade_rect.color = Color(
		color.r,
		color.g,
		color.b,
		1.0,
	)
	_fade_rect.show()

	_fade_tween = NucleusUIMotion.create_tween(
		_fade_rect,
		fade_motion,
	)
	_fade_tween.tween_property(
		_fade_rect,
		"modulate:a",
		clampf(color.a, 0.0, 1.0),
		NucleusUIMotion.get_duration(fade_motion),
	)
	_fade_tween.finished.connect(
		_on_covered,
		CONNECT_ONE_SHOT,
	)

	return _fade_tween


func fade_from() -> Tween:
	_kill_fade_tween()

	if not _fade_rect.visible:
		_fade_rect.show()
		_fade_rect.modulate.a = 1.0

	_fade_tween = NucleusUIMotion.create_tween(
		_fade_rect,
		fade_motion,
	)
	_fade_tween.tween_property(
		_fade_rect,
		"modulate:a",
		0.0,
		NucleusUIMotion.get_duration(fade_motion),
	)
	_fade_tween.finished.connect(
		_on_revealed,
		CONNECT_ONE_SHOT,
	)

	return _fade_tween


func cover_and_reveal(
	color: Color = Color.BLACK,
	hold_seconds: float = 0.0,
) -> void:
	await fade_to(color).finished

	if hold_seconds > 0.0:
		await get_tree().create_timer(
			hold_seconds,
			true,
			false,
			true,
		).timeout

	await fade_from().finished


func flash(
	color: Color = Color.WHITE,
	intensity: float = 1.0,
) -> Tween:
	var overlay: ColorRect = _create_overlay()
	var effective_intensity: float = clampf(
		intensity,
		0.0,
		1.0,
	) * NucleusUIMotionPolicy.get_screen_flash_intensity()

	overlay.color = Color(
		color.r,
		color.g,
		color.b,
		1.0,
	)
	overlay.modulate.a = clampf(
		color.a * effective_intensity,
		0.0,
		1.0,
	)

	flash_started.emit()

	var tween: Tween = NucleusUIMotion.create_tween(
		overlay,
		flash_motion,
	)
	tween.tween_property(
		overlay,
		"modulate:a",
		0.0,
		NucleusUIMotion.get_duration(flash_motion),
	)
	tween.finished.connect(
		_on_flash_finished.bind(overlay),
		CONNECT_ONE_SHOT,
	)

	return tween


func clear_immediately() -> void:
	_kill_fade_tween()

	_fade_rect.hide()
	_fade_rect.modulate.a = 0.0


func _create_overlay() -> ColorRect:
	var overlay := ColorRect.new()

	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(overlay)

	return overlay


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = null


func _on_covered() -> void:
	_fade_tween = null
	covered.emit()


func _on_revealed() -> void:
	_fade_tween = null
	_fade_rect.hide()
	revealed.emit()


func _on_flash_finished(overlay: ColorRect) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()

	flash_finished.emit()
