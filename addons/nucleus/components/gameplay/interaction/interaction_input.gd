class_name NucleusInteractionInput
extends Node
## Routes the semantic interaction action to one [NucleusInteractor].
##
## Single-player uses normal Godot unhandled input. Couch multiplayer can bind a
## [NucleusLocalPlayerInput], reusing the device routing already owned by Core.

signal interaction_input(
	error: Error,
	interactable: NucleusInteractable,
)

@export var interactor: NucleusInteractor
@export var action: StringName = NucleusInputActions.INTERACT
@export var use_global_input: bool = true
@export var mark_global_input_handled: bool = true

var local_player_input: NucleusLocalPlayerInput


func _ready() -> void:
	if interactor == null:
		interactor = get_parent() as NucleusInteractor

	if interactor == null:
		NucleusLog.error(
			"%s requires a NucleusInteractor." % get_path(),
			&"InteractionInput",
		)


func _exit_tree() -> void:
	unbind_local_player_input()


func bind_local_player_input(
	player_input: NucleusLocalPlayerInput,
) -> void:
	unbind_local_player_input()

	local_player_input = player_input

	if local_player_input:
		local_player_input.input_received.connect(
			_on_local_input_received
		)


func unbind_local_player_input() -> void:
	if (
		local_player_input
		and local_player_input.input_received.is_connected(
			_on_local_input_received
		)
	):
		local_player_input.input_received.disconnect(
			_on_local_input_received
		)

	local_player_input = null


func _unhandled_input(event: InputEvent) -> void:
	if not use_global_input or local_player_input:
		return

	if not event.is_action_pressed(action):
		return

	var error: Error = _try_interact()

	if error == OK and mark_global_input_handled:
		get_viewport().set_input_as_handled()


func _on_local_input_received(event: InputEvent) -> void:
	if event.is_action_pressed(action):
		_try_interact()


func _try_interact() -> Error:
	if interactor == null:
		return ERR_UNCONFIGURED

	var target: NucleusInteractable = interactor.current
	var error: Error = interactor.interact_current()

	interaction_input.emit(
		error,
		target,
	)

	return error
