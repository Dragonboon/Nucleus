class_name NucleusNetworkUtils
extends RefCounted
## Stateless networking helpers for common transport setup and diagnostics.

const MIN_UNPRIVILEGED_PORT: int = 1024
const MAX_PORT: int = 65535
const LOCALHOST_IPV4: String = "127.0.0.1"


static func is_valid_port(
	port: int,
	include_privileged: bool = false,
) -> bool:
	var minimum_port: int = (
		1
		if include_privileged
		else MIN_UNPRIVILEGED_PORT
	)

	return port >= minimum_port and port <= MAX_PORT


static func random_port(
	include_privileged: bool = false,
) -> int:
	var minimum_port: int = (
		1
		if include_privileged
		else MIN_UNPRIVILEGED_PORT
	)

	return randi_range(minimum_port, MAX_PORT)


static func generate_nonce(byte_count: int = 16) -> String:
	if byte_count <= 0:
		return ""

	return Crypto.new().generate_random_bytes(
		byte_count
	).hex_encode()


static func get_local_ipv4_addresses(
	private_only: bool = true,
) -> Array[String]:
	var addresses: Array[String] = []

	for address: String in IP.get_local_addresses():
		if ":" in address:
			continue

		if not address.is_valid_ip_address():
			continue

		if private_only and not _is_private_ipv4(address):
			continue

		addresses.append(address)

	addresses.sort_custom(_sort_ipv4_preference)

	return addresses


static func get_preferred_local_ipv4() -> String:
	var addresses: Array[String] = get_local_ipv4_addresses(true)

	return (
		LOCALHOST_IPV4
		if addresses.is_empty()
		else addresses.front()
	)


static func is_valid_websocket_url(url: String) -> bool:
	var normalized_url: String = url.strip_edges().to_lower()

	return (
		normalized_url.begins_with("ws://")
		or normalized_url.begins_with("wss://")
	)


static func _is_private_ipv4(address: String) -> bool:
	if address.begins_with("10."):
		return true

	if address.begins_with("192.168."):
		return true

	if not address.begins_with("172."):
		return false

	var segments: PackedStringArray = address.split(".")

	if segments.size() != 4:
		return false

	var second_octet: int = int(segments[1])

	return second_octet >= 16 and second_octet <= 31


static func _sort_ipv4_preference(
	left: String,
	right: String,
) -> bool:
	return _ipv4_priority(left) < _ipv4_priority(right)


static func _ipv4_priority(address: String) -> int:
	if address.begins_with("192.168."):
		return 0

	if address.begins_with("10."):
		return 1

	if address.begins_with("172."):
		return 2

	return 3
