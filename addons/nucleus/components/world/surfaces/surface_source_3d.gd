@tool
class_name NucleusSurfaceSource3D
extends Node
## Extension point that resolves one semantic surface from collision context.
##
## Attach sources below the node whose surface semantics they own. Subclasses
## may use the query position, normal, shape index, or face index to choose a
## profile dynamically.

@export var enabled: bool = true
@export var priority: int = 0


func resolve_surface(
	query: NucleusSurfaceQuery3D,
) -> NucleusSurfaceProfile:
	if not enabled or query == null or not query.is_valid():
		return null

	return _resolve_surface(query)


func _resolve_surface(
	_query: NucleusSurfaceQuery3D,
) -> NucleusSurfaceProfile:
	return null
