class_name NucleusUIDialog
extends Node
## Lightweight dialog adapter for an existing modal panel.
##
## It keeps text/button wiring out of the modal stack and does not impose a
## visual layout or Theme.

signal confirmed
signal canceled

@export var modal: NucleusUIModal

@export_group("Content")
@export var title_label: Label
@export var message_label: Label

@export_group("Buttons")
@export var confirm_button: BaseButton
@export var cancel_button: BaseButton

@export_group("Translation")
@export var title_key: StringName
@export var message_key: StringName
@export var confirm_text_key: StringName
@export var cancel_text_key: StringName

@export var fallback_title: String = ""
@export_multiline var fallback_message: String = ""
@export var fallback_confirm_text: String = "OK"
@export var fallback_cancel_text: String = "Cancel"


func _ready() -> void:
	_resolve_modal()
	_apply_text()

	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree():
		_apply_text()


func configure(
	title: String,
	message: String,
	confirm_text: String = "",
	cancel_text: String = "",
) -> void:
	title_key = &""
	message_key = &""
	confirm_text_key = &""
	cancel_text_key = &""

	fallback_title = title
	fallback_message = message

	if not confirm_text.is_empty():
		fallback_confirm_text = confirm_text

	if not cancel_text.is_empty():
		fallback_cancel_text = cancel_text

	_apply_text()


func _resolve_modal() -> void:
	if modal:
		return

	var parent: Node = get_parent()

	if parent == null:
		return

	for node: Node in NucleusNodeUtils.descendants(parent):
		if node is NucleusUIModal:
			modal = node as NucleusUIModal
			return


func _apply_text() -> void:
	if title_label:
		title_label.text = _resolve_text(
			title_key,
			fallback_title,
		)

	if message_label:
		message_label.text = _resolve_text(
			message_key,
			fallback_message,
		)

	if confirm_button is Button:
		(confirm_button as Button).text = _resolve_text(
			confirm_text_key,
			fallback_confirm_text,
		)

	if cancel_button is Button:
		(cancel_button as Button).text = _resolve_text(
			cancel_text_key,
			fallback_cancel_text,
		)


func _resolve_text(
	key: StringName,
	fallback: String,
) -> String:
	if key == &"":
		return str(TranslationServer.translate(fallback))

	var translated: String = str(
		TranslationServer.translate(key)
	)

	return fallback if translated == str(key) else translated


func _on_confirm_pressed() -> void:
	if modal:
		modal.request_accept()

	confirmed.emit()


func _on_cancel_pressed() -> void:
	if modal:
		modal.request_cancel()

	canceled.emit()
