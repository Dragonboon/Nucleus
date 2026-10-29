class_name NucleusWarmupSequence
extends Node
## Scene-owned first-use warmup for explicitly authored PackedScenes.
##
## This component amortizes scene instantiation. It does not guarantee GPU
## pipeline compilation; games that require that should author a rendered
## warmup scene and verify the result with performance pipeline counters.

signal warmup_started(plan: NucleusWarmupPlan, total_instances: int)
signal entry_started(entry: NucleusWarmupEntry)
signal progress_changed(progress: float, processed: int, total: int)
signal entry_completed(entry: NucleusWarmupEntry)
signal warmup_completed(plan: NucleusWarmupPlan)
signal warmup_failed(entry: NucleusWarmupEntry, error: Error)

@export var plan: NucleusWarmupPlan
@export_range(1, 128, 1, "or_greater")
var max_instances_per_frame: int = 2
@export var auto_run: bool = false

var _running: bool = false


func _ready() -> void:
	if auto_run:
		_run_auto.call_deferred()


func is_running() -> bool:
	return _running


func run(override_plan: NucleusWarmupPlan = null) -> Error:
	if _running:
		return ERR_BUSY
	if not is_inside_tree():
		return ERR_UNCONFIGURED

	var resolved_plan: NucleusWarmupPlan = override_plan if override_plan else plan
	if resolved_plan == null:
		return ERR_INVALID_PARAMETER
	if not resolved_plan.get_validation_errors().is_empty():
		return ERR_INVALID_PARAMETER

	_running = true
	var total: int = resolved_plan.get_total_instances()
	var processed: int = 0
	var frame_instances: int = 0
	warmup_started.emit(resolved_plan, total)
	progress_changed.emit(0.0 if total > 0 else 1.0, processed, total)

	for entry: NucleusWarmupEntry in resolved_plan.entries:
		entry_started.emit(entry)
		for _index: int in range(entry.instance_count):
			var instance: Node = entry.scene.instantiate()
			if instance == null:
				_running = false
				warmup_failed.emit(entry, ERR_CANT_CREATE)
				return ERR_CANT_CREATE

			if entry.mode == NucleusWarmupEntry.Mode.ENTER_TREE_INACTIVE:
				_prepare_inactive(instance)
				add_child(instance)
				for _frame: int in range(entry.settle_frames):
					await get_tree().process_frame
				remove_child(instance)

			instance.free()
			processed += 1
			frame_instances += 1
			progress_changed.emit(
				float(processed) / float(maxi(total, 1)),
				processed,
				total,
			)

			if frame_instances >= max_instances_per_frame and processed < total:
				frame_instances = 0
				await get_tree().process_frame

		entry_completed.emit(entry)

	_running = false
	warmup_completed.emit(resolved_plan)
	return OK


func _run_auto() -> void:
	await run()


func _prepare_inactive(instance: Node) -> void:
	instance.process_mode = Node.PROCESS_MODE_DISABLED
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	elif instance is Node3D:
		(instance as Node3D).visible = false
