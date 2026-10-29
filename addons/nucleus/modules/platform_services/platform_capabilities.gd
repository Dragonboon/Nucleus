class_name NucleusPlatformCapabilities
extends RefCounted
## Provider-agnostic capability identifiers.
##
## Capabilities advertise support only. They do not define SDK semantics.

const IDENTITY: StringName = &"identity"
const ACHIEVEMENTS: StringName = &"achievements"
const STATS: StringName = &"stats"
const CLOUD_STORAGE: StringName = &"cloud_storage"
const RICH_PRESENCE: StringName = &"rich_presence"
const FRIENDS: StringName = &"friends"
const LOBBIES: StringName = &"lobbies"
const AUTH: StringName = &"auth"
const COMMERCE: StringName = &"commerce"
const OVERLAY: StringName = &"overlay"
const NETWORK_PEER: StringName = &"network_peer"


static func all() -> Array[StringName]:
	var result: Array[StringName] = [
		IDENTITY,
		ACHIEVEMENTS,
		STATS,
		CLOUD_STORAGE,
		RICH_PRESENCE,
		FRIENDS,
		LOBBIES,
		AUTH,
		COMMERCE,
		OVERLAY,
		NETWORK_PEER,
	]
	return result
