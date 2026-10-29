class_name NucleusTargetResolver
extends RefCounted
## Resolves physics/sensor Nodes to the nearest NucleusTargetable endpoint.


static func find_targetable(source: Node) -> NucleusTargetable:
	if source == null:
		return null

	if source is NucleusTargetable:
		return source as NucleusTargetable

	for node: Node in NucleusNodeUtils.descendants(source):
		if node is NucleusTargetable:
			return node as NucleusTargetable

	for ancestor: Node in NucleusNodeUtils.ancestors(source):
		if ancestor is NucleusTargetable:
			return ancestor as NucleusTargetable

		for child: Node in ancestor.get_children():
			if child is NucleusTargetable:
				return child as NucleusTargetable

	return null


static func find_agent(source: Node) -> NucleusTargetingAgent:
	if source == null:
		return null

	if source is NucleusTargetingAgent:
		return source as NucleusTargetingAgent

	for ancestor: Node in NucleusNodeUtils.ancestors(source):
		if ancestor is NucleusTargetingAgent:
			return ancestor as NucleusTargetingAgent

		for child: Node in ancestor.get_children():
			if child is NucleusTargetingAgent:
				return child as NucleusTargetingAgent

	return null
