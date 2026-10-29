@abstract
class_name NucleusSettingDefinition
extends Resource
## Immutable metadata that describes one user-facing setting.
##
## Runtime values never live in this Resource. [NucleusSettingsService] owns
## the active value, while this Resource only defines identity, defaults,
## validation, and presentation metadata.

@export_group("Identity")
@export var section: StringName
@export var key: StringName

@export_group("Presentation")
@export var display_name: String
@export_multiline var description: String
@export var requires_restart: bool = false


## Returns the globally unique setting identifier in "section/key" form.
func get_id() -> StringName:
	if section == &"" or key == &"":
		return &""

	return StringName("%s/%s" % [section, key])


## Returns validation problems in the definition itself.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()

	if section == &"":
		errors.append("section cannot be empty")

	if key == &"":
		errors.append("key cannot be empty")

	return errors


## Returns the default runtime value for this setting.
@abstract func get_default_value() -> Variant


## Returns whether a Variant is compatible with this setting type.
@abstract func accepts_value(value: Variant) -> bool


## Returns a sanitized value after the type has been accepted.
@abstract func normalize_value(value: Variant) -> Variant
