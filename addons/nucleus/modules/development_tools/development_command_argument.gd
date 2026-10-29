class_name NucleusDevelopmentCommandArgument
extends RefCounted
## Typed argument contract for one development command parameter.

var name: StringName
var value_type: int = TYPE_STRING
var description: String = ""
var optional: bool = false
var default_value: Variant
var choices := PackedStringArray()


static func build(
	p_name: StringName,
	p_value_type: int = TYPE_STRING,
	p_description: String = "",
	p_optional: bool = false,
	p_default_value: Variant = null,
	p_choices: PackedStringArray = PackedStringArray(),
) -> NucleusDevelopmentCommandArgument:
	var argument := NucleusDevelopmentCommandArgument.new()
	argument.name = p_name
	argument.value_type = p_value_type
	argument.description = p_description
	argument.optional = p_optional
	argument.default_value = p_default_value
	argument.choices = p_choices.duplicate()
	return argument


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if name.is_empty():
		errors.append("argument name cannot be empty")
	if value_type not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
		errors.append("unsupported argument type for '%s'" % str(name))
	if optional and default_value != null:
		var default_type := typeof(default_value)
		var compatible := default_type == value_type
		if value_type == TYPE_FLOAT and default_type == TYPE_INT:
			compatible = true
		if not compatible:
			errors.append("default value type does not match '%s'" % str(name))
	return errors


func parse(token: String) -> Dictionary:
	var value: Variant
	match value_type:
		TYPE_STRING:
			value = token
		TYPE_INT:
			if not token.is_valid_int():
				return _parse_error("expected an integer")
			value = token.to_int()
		TYPE_FLOAT:
			if not token.is_valid_float():
				return _parse_error("expected a number")
			value = token.to_float()
		TYPE_BOOL:
			var normalized := token.strip_edges().to_lower()
			match normalized:
				"true", "1", "yes", "on":
					value = true
				"false", "0", "no", "off":
					value = false
				_:
					return _parse_error("expected true/false, yes/no, on/off, or 1/0")
		_:
			return _parse_error("unsupported argument type")

	if not choices.is_empty():
		var match_found := false
		for choice: String in choices:
			if str(value).nocasecmp_to(choice) == 0:
				match_found = true
				break
		if not match_found:
			return _parse_error(
				"expected one of: %s" % ", ".join(choices)
			)

	return {
		"ok": true,
		"value": value,
	}


func usage_token() -> String:
	var token := str(name)
	if not choices.is_empty():
		token += "=%s" % "|".join(choices)
	if optional:
		return "[%s]" % token
	return "<%s>" % token


func _parse_error(reason: String) -> Dictionary:
	return {
		"ok": false,
		"error": "%s: %s" % [str(name), reason],
	}
