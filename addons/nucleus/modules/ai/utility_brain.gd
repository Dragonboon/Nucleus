@tool
class_name NucleusAIUtilityBrain
extends Node
## Scene-owned utility selector.
##
## The brain chooses an intention. It does not execute movement, attacks,
## animation, or state transitions by itself.

signal decision_changed(
	current: NucleusAIUtilityOption,
	previous: NucleusAIUtilityOption,
	score: float,
	context: Dictionary,
)
signal evaluation_completed(
	current: NucleusAIUtilityOption,
	score: float,
	context: Dictionary,
)

@export var options: Array[NucleusAIUtilityOption] = []:
	set(value):
		options = value
		update_configuration_warnings()

@export var context_root: Node
@export var active: bool = true:
	set(value):
		active = value

		if is_node_ready() and not Engine.is_editor_hint():
			_refresh_evaluation_driver()

@export_group("Evaluation")
@export var automatic_evaluation: bool = true
@export_range(0.0, 60.0, 0.01, "or_greater")
var evaluation_interval: float = 0.25
@export_range(0.0, 1.0, 0.001)
var minimum_score: float = 0.001
@export_range(0.0, 1.0, 0.001)
var current_option_bonus: float = 0.05

@export_group("Scheduling")
## Optional scene-owned scheduler. When assigned and evaluation_interval > 0,
## automatic evaluations are staggered with the scheduler instead of polling
## every physics frame.
@export var update_scheduler: NucleusUpdateScheduler
@export_range(-1.0, 1.0, 0.001)
var evaluation_phase: float = -1.0
@export var evaluation_priority: int = 0

var current_option: NucleusAIUtilityOption
var _elapsed: float = 0.0
var _evaluation_requested: bool = true
var _last_context: Dictionary = {}
var _last_scores: Dictionary = {}
var _context_providers: Array[NucleusAIContextProvider] = []
var _scheduler_token: int = -1


func _enter_tree() -> void:
	if is_node_ready() and not Engine.is_editor_hint():
		_connect_context_providers()
		_refresh_evaluation_driver()


func _ready() -> void:
	if context_root == null:
		context_root = self

	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	_connect_context_providers()
	_refresh_evaluation_driver()


func _exit_tree() -> void:
	_unregister_scheduler_task()
	_disconnect_context_providers()


func _physics_process(delta: float) -> void:
	if not active or not automatic_evaluation:
		return

	_elapsed += delta

	if (
		not _evaluation_requested
		and evaluation_interval > 0.0
		and _elapsed < evaluation_interval
	):
		return

	_elapsed = 0.0
	_evaluation_requested = false
	evaluate()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var known_ids: Dictionary[StringName, bool] = {}

	if options.is_empty():
		warnings.append("Add at least one NucleusAIUtilityOption.")

	for index: int in range(options.size()):
		var option: NucleusAIUtilityOption = options[index]

		if option == null:
			warnings.append("AI option %d is null." % index)
			continue

		if option.option_id == &"":
			warnings.append("AI option %d has an empty option_id." % index)
			continue

		if known_ids.has(option.option_id):
			warnings.append(
				"Duplicate AI option_id '%s'." % option.option_id
			)
			continue

		known_ids[option.option_id] = true

	return warnings


func evaluate(
	extra_context: Dictionary = {},
) -> NucleusAIUtilityOption:
	var context: Dictionary = _build_context(
		extra_context
	)
	var best: NucleusAIUtilityOption = null
	var best_score: float = -1.0
	var best_priority: int = -2147483648

	_last_scores.clear()

	for option: NucleusAIUtilityOption in options:
		if option == null or option.option_id == &"":
			continue

		var option_score: float = option.evaluate(context)

		if option == current_option:
			option_score = minf(
				1.0,
				option_score + current_option_bonus,
			)

		_last_scores[option.option_id] = option_score

		if option_score < minimum_score:
			continue

		if (
			best == null
			or option_score > best_score
			or (
				is_equal_approx(
					option_score,
					best_score,
				)
				and option.priority > best_priority
			)
		):
			best = option
			best_score = option_score
			best_priority = option.priority

	_set_current(
		best,
		best_score if best != null else 0.0,
		context,
	)
	evaluation_completed.emit(
		current_option,
		best_score if best != null else 0.0,
		context.duplicate(),
	)

	return current_option


func request_evaluation() -> void:
	_evaluation_requested = true

	if (
		update_scheduler != null
		and is_instance_valid(update_scheduler)
		and _scheduler_token != -1
	):
		update_scheduler.request_task(_scheduler_token)


func refresh_context_providers() -> void:
	_disconnect_context_providers()
	_connect_context_providers()
	request_evaluation()


func set_active(enabled: bool) -> void:
	active = enabled


func get_last_context() -> Dictionary:
	return _last_context.duplicate()


func get_last_scores() -> Dictionary:
	return _last_scores.duplicate()


func get_score(option_id: StringName) -> float:
	return float(
		_last_scores.get(
			option_id,
			0.0,
		)
	)


func _build_context(
	extra_context: Dictionary,
) -> Dictionary:
	var context: Dictionary = {
		&"actor": get_parent(),
		&"brain": self,
	}

	for provider: NucleusAIContextProvider in _context_providers:
		if provider != null and is_instance_valid(provider):
			provider.contribute(context)

	for key: Variant in extra_context:
		context[key] = extra_context[key]

	_last_context = context.duplicate()
	return context


func _set_current(
	next: NucleusAIUtilityOption,
	score: float,
	context: Dictionary,
) -> void:
	if current_option == next:
		return

	var previous: NucleusAIUtilityOption = current_option
	current_option = next

	decision_changed.emit(
		current_option,
		previous,
		score,
		context.duplicate(),
	)


func _get_context_providers() -> Array[NucleusAIContextProvider]:
	var providers: Array[NucleusAIContextProvider] = []

	if context_root == null:
		return providers

	if context_root is NucleusAIContextProvider:
		providers.append(
			context_root as NucleusAIContextProvider
		)

	for node: Node in NucleusNodeUtils.descendants(
		context_root,
		true,
	):
		if node is NucleusAIContextProvider:
			providers.append(
				node as NucleusAIContextProvider
			)

	return providers


func _connect_context_providers() -> void:
	_context_providers = _get_context_providers()

	for provider: NucleusAIContextProvider in _context_providers:
		if not provider.context_changed.is_connected(
			request_evaluation
		):
			provider.context_changed.connect(
				request_evaluation
			)


func _disconnect_context_providers() -> void:
	for provider: NucleusAIContextProvider in _context_providers:
		if (
			provider != null
			and is_instance_valid(provider)
			and provider.context_changed.is_connected(
				request_evaluation
			)
		):
			provider.context_changed.disconnect(
				request_evaluation
			)

	_context_providers.clear()


func _refresh_evaluation_driver() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return

	var use_scheduler: bool = (
		active
		and automatic_evaluation
		and update_scheduler != null
		and evaluation_interval > 0.0
	)

	if use_scheduler:
		_register_scheduler_task()
		set_physics_process(false)
		return

	_unregister_scheduler_task()
	set_physics_process(active and automatic_evaluation)


func _register_scheduler_task() -> void:
	if update_scheduler == null or _scheduler_token != -1:
		return

	_scheduler_token = update_scheduler.register_task(
		Callable(self, "_on_scheduled_evaluation"),
		evaluation_interval,
		evaluation_phase,
		evaluation_priority,
	)

	if _scheduler_token != -1 and not active:
		update_scheduler.set_task_enabled(_scheduler_token, false)


func _unregister_scheduler_task() -> void:
	if (
		update_scheduler != null
		and is_instance_valid(update_scheduler)
		and _scheduler_token != -1
	):
		update_scheduler.unregister_task(_scheduler_token)
	_scheduler_token = -1


func _on_scheduled_evaluation(_elapsed_seconds: float) -> void:
	if not is_inside_tree() or not can_process() or not active or not automatic_evaluation:
		return

	_elapsed = 0.0
	_evaluation_requested = false
	evaluate()
