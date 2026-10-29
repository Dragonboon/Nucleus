class_name NucleusNetworkTypes
extends RefCounted
## Shared enums for the optional Nucleus networking module.

enum State {
	OFFLINE,
	STARTING,
	CONNECTING,
	SERVER,
	CLIENT,
}

enum Transport {
	NONE,
	ENET,
	WEBSOCKET,
}
