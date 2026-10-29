@tool
class_name NucleusPlacementVariantSet3D
extends Resource
## Authored alternatives for one construction item (roof, window, wall, etc.).
## Reference this Resource from the session, NOT the scenes it contains:
## a scene referencing a catalog that references the same scene forms a cycle.

@export var default_variant_id: StringName = &""
@export var variants: Array[NucleusPlacementVariant3D] = []


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if variants.is_empty() or variants.size() > 32:
		errors.append("Provide between 1 and 32 variants.")
	var ids: Dictionary = {}
	for i in range(variants.size()):
		var variant: NucleusPlacementVariant3D = variants[i]
		if variant == null:
			errors.append("variants[%d] is null." % i)
			continue
		for error: String in variant.validate():
			errors.append("variants[%d]: %s" % [i, error])
		if variant.variant_id != &"":
			if ids.has(variant.variant_id):
				errors.append("Duplicate variant_id '%s'." % variant.variant_id)
			ids[variant.variant_id] = true
	if default_variant_id != &"" and not ids.has(default_variant_id):
		errors.append("default_variant_id must reference an existing variant.")
	return errors


func find_index(variant_id: StringName) -> int:
	for i in range(variants.size()):
		if variants[i] != null and variants[i].variant_id == variant_id:
			return i
	return -1


func get_default_index() -> int:
	return find_index(default_variant_id) if default_variant_id != &"" else 0
