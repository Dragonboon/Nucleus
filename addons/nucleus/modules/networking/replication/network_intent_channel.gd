class_name NucleusNetworkIntentChannel
extends Node
## Client-to-authority gameplay-intent transport.
##
## The server never trusts the payload merely because this component accepted
## transport-level shape, sequence, ownership, and rate checks. Override
## validate_intent() for game-specific authorization and semantic validation.

signal intent_received(
	peer_id: int,
	intent_id: StringName,
	payload: Dictionary,
	reliable: bool,
	sequence: int,
)
signal intent_rejected(
	peer_id: int,
	intent_id: StringName,
	error: Error,
)

const SERVER_PEER_ID: int = 1
const STREAM_RELIABLE: StringName = &"reliable"
const STREAM_UNRELIABLE: StringName = &"unreliable"

@export_range(1, 2147483647, 1)
var controlling_peer_id: int = SERVER_PEER_ID

@export_group("Admission")
@export_range(0, 10000, 1, "or_greater")
var max_intents_per_second: int = 120
@export_range(1, 256, 1)
var max_payload_entries: int = 32
@export_range(1, 256, 1)
var max_intent_id_length: int = 64
@export var active: bool = true

var _local_reliable_sequence: int = 0
var _local_unreliable_sequence: int = 0
var _sequence_tracker := NucleusNetworkSequenceTracker.new()
var _rate_limiter := NucleusNetworkRateLimiter.new()


func submit_reliable(
	intent_id: StringName,
	payload: Dictionary = {},
) -> Error:
	_local_reliable_sequence += 1

	return _submit(
		true,
		_local_reliable_sequence,
		intent_id,
		payload,
	)


func submit_unreliable(
	intent_id: StringName,
	payload: Dictionary = {},
) -> Error:
	_local_unreliable_sequence += 1

	return _submit(
		false,
		_local_unreliable_sequence,
		intent_id,
		payload,
	)


func validate_intent(
	_peer_id: int,
	_intent_id: StringName,
	_payload: Dictionary,
	_reliable: bool,
) -> Error:
	return OK


func reset_peer_admission(peer_id: int) -> void:
	_sequence_tracker.reset_peer(peer_id)
	_rate_limiter.reset_peer(peer_id)


func _submit(
	reliable: bool,
	sequence: int,
	intent_id: StringName,
	payload: Dictionary,
) -> Error:
	if not active:
		return ERR_UNAVAILABLE

	var shape_error: Error = _validate_shape(
		intent_id,
		payload,
	)

	if shape_error != OK:
		return shape_error

	var local_peer_id: int = multiplayer.get_unique_id()

	if local_peer_id != controlling_peer_id:
		return ERR_UNAVAILABLE

	if multiplayer.is_server():
		return _accept_intent(
			local_peer_id,
			sequence,
			intent_id,
			payload,
			reliable,
		)

	if reliable:
		_receive_reliable_intent.rpc_id(
			SERVER_PEER_ID,
			sequence,
			String(intent_id),
			payload,
		)
	else:
		_receive_unreliable_intent.rpc_id(
			SERVER_PEER_ID,
			sequence,
			String(intent_id),
			payload,
		)

	return OK


@rpc("any_peer", "call_remote", "reliable", 1)
func _receive_reliable_intent(
	sequence: int,
	intent_id: String,
	payload: Dictionary,
) -> void:
	if not multiplayer.is_server():
		return

	_accept_intent(
		multiplayer.get_remote_sender_id(),
		sequence,
		StringName(intent_id),
		payload,
		true,
	)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _receive_unreliable_intent(
	sequence: int,
	intent_id: String,
	payload: Dictionary,
) -> void:
	if not multiplayer.is_server():
		return

	_accept_intent(
		multiplayer.get_remote_sender_id(),
		sequence,
		StringName(intent_id),
		payload,
		false,
	)


func _accept_intent(
	peer_id: int,
	sequence: int,
	intent_id: StringName,
	payload: Dictionary,
	reliable: bool,
) -> Error:
	if not active:
		return _reject(
			peer_id,
			intent_id,
			ERR_UNAVAILABLE,
		)

	if peer_id != controlling_peer_id:
		return _reject(
			peer_id,
			intent_id,
			ERR_UNAVAILABLE,
		)

	var shape_error: Error = _validate_shape(
		intent_id,
		payload,
	)

	if shape_error != OK:
		return _reject(
			peer_id,
			intent_id,
			shape_error,
		)

	var stream_id: StringName = (
		STREAM_RELIABLE
		if reliable
		else STREAM_UNRELIABLE
	)

	if not _sequence_tracker.accept(
		peer_id,
		stream_id,
		sequence,
	):
		return _reject(
			peer_id,
			intent_id,
			ERR_INVALID_PARAMETER,
		)

	if not _rate_limiter.allow(
		peer_id,
		Time.get_ticks_msec(),
		max_intents_per_second,
	):
		return _reject(
			peer_id,
			intent_id,
			ERR_BUSY,
		)

	var validation_error: Error = validate_intent(
		peer_id,
		intent_id,
		payload,
		reliable,
	)

	if validation_error != OK:
		return _reject(
			peer_id,
			intent_id,
			validation_error,
		)

	intent_received.emit(
		peer_id,
		intent_id,
		payload.duplicate(true),
		reliable,
		sequence,
	)

	return OK


func _validate_shape(
	intent_id: StringName,
	payload: Dictionary,
) -> Error:
	if intent_id == &"":
		return ERR_INVALID_PARAMETER

	if String(intent_id).length() > max_intent_id_length:
		return ERR_INVALID_PARAMETER

	if payload.size() > max_payload_entries:
		return ERR_INVALID_PARAMETER

	return OK


func _reject(
	peer_id: int,
	intent_id: StringName,
	error: Error,
) -> Error:
	intent_rejected.emit(
		peer_id,
		intent_id,
		error,
	)
	return error
