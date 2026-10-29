class_name NucleusActionContextProvider
extends Node
## Optional context contributor used by Action execution adapters.
##
## Providers are side-effect free. They enrich a Dictionary before
## NucleusGameplayAction validation/execution.

func contribute(_context: Dictionary) -> void:
	pass


static func contribute_from(
	root: Node,
	context: Dictionary,
) -> void:
	if root == null:
		return

	if root is NucleusActionContextProvider:
		(root as NucleusActionContextProvider).contribute(
			context
		)

	for node: Node in NucleusNodeUtils.descendants(
		root,
		true,
	):
		if node is NucleusActionContextProvider:
			(node as NucleusActionContextProvider).contribute(
				context
			)
