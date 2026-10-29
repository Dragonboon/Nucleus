@tool
class_name NucleusStateTransitionPolicy
extends Resource
## Optional bounded buffering for NucleusStateMachine.request_state().
## A null policy preserves strictly immediate transitions.

@export_range(1, 16, 1) var capacity: int = 1
## When full, replace the newest pending request. Otherwise reject the new request.
@export var replace_latest: bool = true
## Zero disables expiration. Time is monotonic and measured while the request is queued.
@export_range(0.0, 60.0, 0.1, "or_greater") var timeout_seconds: float = 0.0
