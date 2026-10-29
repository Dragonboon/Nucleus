class_name NucleusTouchActionButton
extends TouchScreenButton
## Multi-touch gameplay button that feeds one semantic InputMap action.

@export var semantic_action: StringName
@export var local_input_session: NucleusLocalInputSession
@export_range(0, 15, 1, "or_greater") var player_index: int = 0
@export var haptic_strength: float = 0.0
@export_range(0.0, 2.0, 0.01) var haptic_duration: float = 0.05


func _ready() -> void:
	# Keep the inherited native action empty so Nucleus owns exactly one route.
	action = &""
	pressed.connect(_on_pressed)
	released.connect(_on_released)


func _exit_tree() -> void:
	_set_strength(0.0)


func _on_pressed() -> void:
	_set_strength(1.0)

	if haptic_strength > 0.0:
		var player_input: NucleusLocalPlayerInput = null
		if local_input_session:
			player_input = local_input_session.get_player(player_index)

		NucleusHaptics.pulse(
			haptic_strength,
			haptic_duration,
			player_input,
		)


func _on_released() -> void:
	_set_strength(0.0)


func _set_strength(strength: float) -> void:
	if semantic_action == &"" or not InputMap.has_action(semantic_action):
		return

	if local_input_session:
		local_input_session.set_touch_action(
			player_index,
			semantic_action,
			strength,
		)
		return

	if strength > 0.0:
		Input.action_press(semantic_action, strength)
	else:
		Input.action_release(semantic_action)
