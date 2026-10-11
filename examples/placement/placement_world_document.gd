extends RefCounted
## Lab-owned, data-only world document. No paths or executable content from saves.
## The consuming game supplies the allowlisted PackedScene catalog.

const SCHEMA_VERSION: int = 1
const MAX_PIECES: int = 384
const MAX_FILE_BYTES: int = 512 * 1024
const MAX_COORDINATE: float = 20000.0


static func capture(roots: Array[Node3D]) -> Dictionary:
	var objects: Array[Dictionary] = []
	for root: Node3D in roots:
		if root == null or not is_instance_valid(root):
			continue
		var placeable := NucleusPlaceable3D.find_in(root)
		if placeable == null or placeable.profile == null:
			continue
		objects.append({
			"id": str(placeable.stable_id),
			"kind": str(placeable.profile.kind),
			"transform": encode_transform(root.global_transform),
		})
	return {"schema_version": SCHEMA_VERSION, "objects": objects}


static func encode_transform(value: Transform3D) -> Array[float]:
	return [
		value.basis.x.x, value.basis.x.y, value.basis.x.z,
		value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z,
		value.origin.x, value.origin.y, value.origin.z,
	]


static func decode_transform(numbers: Array) -> Transform3D:
	return Transform3D(
		Basis(
			Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2])),
			Vector3(float(numbers[3]), float(numbers[4]), float(numbers[5])),
			Vector3(float(numbers[6]), float(numbers[7]), float(numbers[8])),
		),
		Vector3(float(numbers[9]), float(numbers[10]), float(numbers[11])),
	)


## Result: {error: Error, message: String, objects: Array[Dictionary]}.
## All fields are checked before the scene owner changes a single Node.
static func validate(document: Variant, catalog: Dictionary) -> Dictionary:
	if not document is Dictionary:
		return _failure("El documento no es un objeto JSON.")
	var data := document as Dictionary
	# Godot JSON may decode integer-looking numbers as floats: validate value,
	# never truncate an unsupported schema such as 1.5 into version 1.
	var schema: Variant = data.get("schema_version")
	if typeof(schema) not in [TYPE_INT, TYPE_FLOAT]:
		return _failure("La version del esquema no es numerica.")
	if not is_finite(float(schema)) or float(schema) != float(SCHEMA_VERSION):
		return _failure("Version de mundo no soportada.")
	var raw: Variant = data.get("objects")
	if not raw is Array:
		return _failure("Falta la lista de objetos.")
	var entries := raw as Array
	if entries.size() > MAX_PIECES:
		return _failure("Demasiados objetos en el mundo.")
	var seen: Dictionary = {}
	var normalized: Array[Dictionary] = []
	for entry: Variant in entries:
		if not entry is Dictionary:
			return _failure("Una pieza no es un objeto JSON.")
		var piece := entry as Dictionary
		if typeof(piece.get("id")) != TYPE_STRING:
			return _failure("ID de pieza invalido.")
		var id: String = piece["id"]
		if not _valid_id(id) or seen.has(id):
			return _failure("ID duplicado o invalido: " + id)
		seen[id] = true
		if typeof(piece.get("kind")) != TYPE_STRING:
			return _failure("Tipo de pieza invalido.")
		var kind: String = piece["kind"]
		if not catalog.has(kind) or not catalog[kind] is PackedScene:
			return _failure("Tipo de pieza no autorizado: " + kind)
		if not piece.get("transform") is Array:
			return _failure("Transformacion ausente.")
		var values := piece["transform"] as Array
		if values.size() != 12:
			return _failure("La transformacion debe contener 12 numeros.")
		for number: Variant in values:
			if typeof(number) not in [TYPE_INT, TYPE_FLOAT]:
				return _failure("La transformacion contiene un valor no numerico.")
			if not is_finite(float(number)):
				return _failure("La transformacion contiene NaN o infinito.")
		var transform := decode_transform(values)
		var basis := transform.basis
		if (
			absf(basis.determinant() - 1.0) > 0.02
			or absf(basis.x.length() - 1.0) > 0.02
			or absf(basis.y.length() - 1.0) > 0.02
			or absf(basis.z.length() - 1.0) > 0.02
			or absf(basis.x.dot(basis.y)) > 0.02
			or absf(basis.y.dot(basis.z)) > 0.02
			or absf(basis.z.dot(basis.x)) > 0.02
		):
			return _failure("Rotacion, escala o reflexion no admitidas.")
		var point := transform.origin
		if (
			absf(point.x) > MAX_COORDINATE
			or absf(point.y) > MAX_COORDINATE
			or absf(point.z) > MAX_COORDINATE
		):
			return _failure("Una pieza esta fuera de los limites de autoría.")
		normalized.append({"id": id, "kind": kind, "transform": values.duplicate()})
	return {"error": OK, "message": "", "objects": normalized}


## Creates all detached instances first. Callers own the returned nodes and must
## attach them only after every entry passes structural/catalog validation.
static func instantiate_validated(document: Variant, catalog: Dictionary) -> Dictionary:
	var result := validate(document, catalog)
	if int(result["error"]) != OK:
		return result
	var prepared: Array[Node3D] = []
	for entry: Dictionary in result["objects"]:
		var packed := catalog[entry["kind"]] as PackedScene
		var candidate: Node = packed.instantiate()
		if not candidate is Node3D:
			if candidate != null:
				candidate.free()
			_free_prepared(prepared)
			return _failure("La escena del catalogo no es Node3D.")
		var root := candidate as Node3D
		var placeable := NucleusPlaceable3D.find_in(root)
		if (
			placeable == null or placeable.profile == null
			or str(placeable.profile.kind) != str(entry["kind"])
			or not placeable.profile.validate().is_empty()
		):
			root.free()
			_free_prepared(prepared)
			return _failure("El asset no coincide con su perfil autorizado.")
		placeable.stable_id = StringName(entry["id"])
		root.transform = decode_transform(entry["transform"])
		prepared.append(root)
	return {"error": OK, "message": "", "roots": prepared}


static func _valid_id(id: String) -> bool:
	if not id.begins_with("p_") or id.length() < 3 or id.length() > 17:
		return false
	for i: int in range(2, id.length()):
		var code := id.unicode_at(i)
		if code < 48 or code > 57:
			return false
	return true


static func _free_prepared(roots: Array[Node3D]) -> void:
	for root: Node3D in roots:
		root.free()


static func _failure(message: String) -> Dictionary:
	return {"error": ERR_INVALID_DATA, "message": message}
