class_name NucleusPlatformUser
extends RefCounted
## Minimal provider-agnostic local-user identity.

var provider_id: StringName
var user_id: String
var display_name: String
var locale: String


func _init(
	value_provider_id: StringName = &"",
	value_user_id: String = "",
	value_display_name: String = "",
	value_locale: String = "",
) -> void:
	provider_id = value_provider_id
	user_id = value_user_id
	display_name = value_display_name
	locale = value_locale


func is_valid() -> bool:
	return (
		provider_id != &""
		and not user_id.is_empty()
	)


func to_dictionary() -> Dictionary:
	return {
		"provider_id": String(provider_id),
		"user_id": user_id,
		"display_name": display_name,
		"locale": locale,
	}
