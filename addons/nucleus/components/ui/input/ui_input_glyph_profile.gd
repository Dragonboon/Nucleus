class_name NucleusInputGlyphProfile
extends Resource
## Maps current InputMap events to game-owned glyph textures.
##
## Nucleus ships no controller/keyboard artwork. The game supplies textures and
## this profile resolves them against the bindings already owned by NucleusInput.

@export_group("Keyboard and mouse")
@export var keyboard_mouse: Array[NucleusInputGlyphEntry] = []

@export_group("Gamepad")
@export var generic_gamepad: Array[NucleusInputGlyphEntry] = []
@export var xbox_gamepad: Array[NucleusInputGlyphEntry] = []
@export var playstation_gamepad: Array[NucleusInputGlyphEntry] = []
@export var nintendo_gamepad: Array[NucleusInputGlyphEntry] = []
@export var steam_gamepad: Array[NucleusInputGlyphEntry] = []

@export_group("Touch")
@export var touch: Array[NucleusInputGlyphEntry] = []


func resolve_event(
	event: InputEvent,
	gamepad_family: int = NucleusInputTypes.GamepadFamily.GENERIC,
) -> Texture2D:
	if event == null:
		return null

	return resolve_key(
		event_key(event),
		NucleusInputBindingCodec.get_source(event),
		gamepad_family,
	)


func resolve_key(
	key: StringName,
	source: int,
	gamepad_family: int = NucleusInputTypes.GamepadFamily.GENERIC,
) -> Texture2D:
	if key == &"":
		return null

	match source:
		NucleusInputTypes.Source.KEYBOARD_MOUSE:
			return _find_texture(keyboard_mouse, key)
		NucleusInputTypes.Source.GAMEPAD:
			var specific := _find_texture(
				_gamepad_entries(gamepad_family),
				key,
			)
			if specific:
				return specific
			return _find_texture(generic_gamepad, key)
		NucleusInputTypes.Source.TOUCH:
			return _find_texture(touch, key)
		_:
			return null


static func event_key(event: InputEvent) -> StringName:
	if event == null:
		return &""

	if event is InputEventKey:
		return _key_event_key(event as InputEventKey)

	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return StringName("mouse:%d" % mouse.button_index)

	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		return StringName("button:%d" % button.button_index)

	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var direction := -1 if motion.axis_value < 0.0 else 1
		return StringName(
			"axis:%d:%d" % [motion.axis, direction]
		)

	if event is InputEventScreenTouch:
		return &"touch"

	if event is InputEventScreenDrag:
		return &"drag"

	return StringName(event.get_class().to_snake_case())


static func _key_event_key(event: InputEventKey) -> StringName:
	var key_code: int = event.key_label

	if key_code == KEY_NONE:
		key_code = event.physical_keycode

	if key_code == KEY_NONE:
		key_code = event.keycode

	return StringName(
		"key:%d:%d:%d:%d:%d"
		% [
			key_code,
			int(event.ctrl_pressed),
			int(event.alt_pressed),
			int(event.shift_pressed),
			int(event.meta_pressed),
		]
	)


func _gamepad_entries(
	gamepad_family: int,
) -> Array[NucleusInputGlyphEntry]:
	match gamepad_family:
		NucleusInputTypes.GamepadFamily.XBOX:
			return xbox_gamepad
		NucleusInputTypes.GamepadFamily.PLAYSTATION:
			return playstation_gamepad
		NucleusInputTypes.GamepadFamily.NINTENDO:
			return nintendo_gamepad
		NucleusInputTypes.GamepadFamily.STEAM:
			return steam_gamepad
		_:
			return generic_gamepad


func _find_texture(
	entries: Array[NucleusInputGlyphEntry],
	key: StringName,
) -> Texture2D:
	for entry: NucleusInputGlyphEntry in entries:
		if entry and entry.event_key == key:
			return entry.texture

	return null
