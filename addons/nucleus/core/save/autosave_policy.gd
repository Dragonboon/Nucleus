class_name NucleusAutosavePolicy
extends Resource
## Scene-owned autosave policy used by [NucleusSaveSession].

@export var enabled: bool = true
@export_range(1.0, 86400.0, 1.0, "or_greater")
var interval_seconds: float = 120.0
@export_range(1, 32, 1, "or_greater") var max_slots: int = 3
@export var save_on_application_pause: bool = true
@export var save_on_application_quit: bool = true
@export var save_on_focus_lost: bool = false
@export_range(0.0, 3600.0, 0.5, "or_greater")
var minimum_interval_seconds: float = 5.0
