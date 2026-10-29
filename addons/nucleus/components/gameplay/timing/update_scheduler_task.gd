extends RefCounted
## Internal mutable record owned by NucleusUpdateScheduler.

var token: int = -1
var callback: Callable
var interval: float = 0.25
var phase: float = 0.0
var priority: int = 0
var enabled: bool = true
var removed: bool = false
var next_due: float = 0.0
var last_run: float = 0.0
