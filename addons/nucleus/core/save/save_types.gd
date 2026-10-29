class_name NucleusSaveTypes
extends RefCounted
## Shared enums for the Nucleus save system.

enum Format {
	BINARY,
	TEXT,
	JSON,
}

enum Encryption {
	NONE,
	PASSWORD,
	RAW_KEY,
}

enum Kind {
	MANUAL,
	AUTOSAVE,
	QUICKSAVE,
}
