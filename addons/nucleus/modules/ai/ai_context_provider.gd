@tool
class_name NucleusAIContextProvider
extends Node
## Side-effect-free runtime context contributor for utility AI evaluation.

signal context_changed


func notify_context_changed() -> void:
	context_changed.emit()


func contribute(_context: Dictionary) -> void:
	pass


static func contribute_from(
	root: Node,
	context: Dictionary,
) -> void:
	if root == null:
		return

	if root is NucleusAIContextProvider:
		(root as NucleusAIContextProvider).contribute(context)

	for node: Node in NucleusNodeUtils.descendants(
		root,
		true,
	):
		if node is NucleusAIContextProvider:
			(node as NucleusAIContextProvider).contribute(context)
