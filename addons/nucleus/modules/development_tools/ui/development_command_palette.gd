class_name NucleusDevelopmentCommandPalette
extends PanelContainer
## Searchable command palette for NucleusDevelopmentCommandRegistry.

signal palette_opened
signal palette_closed

@export var registry_path: NodePath
@export_range(1, 50, 1) var max_results: int = 12
@export_range(1, 20, 1) var history_lines: int = 6
@export var manage_cursor: bool = true

@onready var _query: LineEdit = %Query
@onready var _command_list: ItemList = %CommandList
@onready var _command_title: Label = %CommandTitle
@onready var _command_id: Label = %CommandId
@onready var _description: Label = %Description
@onready var _usage: Label = %Usage
@onready var _output: RichTextLabel = %Output

var _registry: NucleusDevelopmentCommandRegistry
var _cursor_mode_before_open: int = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_registry = get_node_or_null(registry_path) as NucleusDevelopmentCommandRegistry
	if _registry == null:
		push_warning("DevelopmentCommandPalette requires a command registry.")
		hide()
		return

	_query.text_changed.connect(_on_query_changed)
	_query.text_submitted.connect(_on_query_submitted)
	_query.gui_input.connect(_on_query_gui_input)
	_command_list.item_selected.connect(_on_item_selected)
	_command_list.item_activated.connect(_on_item_activated)
	_registry.command_registered.connect(_on_registry_changed)
	_registry.command_unregistered.connect(_on_registry_changed)
	_registry.command_executed.connect(_on_command_executed)
	_registry.history_cleared.connect(_on_history_cleared)
	hide()
	_refresh_results()
	_refresh_history()


func _exit_tree() -> void:
	if visible and manage_cursor:
		NucleusCursor.set_mode(_cursor_mode_before_open)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_palette()
		get_viewport().set_input_as_handled()


func open_palette() -> void:
	if visible:
		_restore_query_focus()
		return
	if manage_cursor:
		_cursor_mode_before_open = NucleusCursor.get_mode()
		NucleusCursor.show()
	show()
	_query.clear()
	_refresh_results()
	_refresh_history()
	_restore_query_focus()
	palette_opened.emit()


func close_palette() -> void:
	if not visible:
		return
	hide()
	if manage_cursor:
		NucleusCursor.set_mode(_cursor_mode_before_open)
	palette_closed.emit()


func is_open() -> bool:
	return visible


func _on_query_changed(_text: String) -> void:
	_refresh_results()


func _on_query_submitted(_text: String) -> void:
	_execute_or_complete()


func _on_query_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_down"):
		_select_relative(1)
		_query.accept_event()
	elif event.is_action_pressed(&"ui_up"):
		_select_relative(-1)
		_query.accept_event()


func _on_item_selected(_index: int) -> void:
	_update_command_detail()


func _on_item_activated(_index: int) -> void:
	var command := _selected_command()
	if command == null:
		return
	_complete_or_execute_command(command)


func _on_registry_changed(_value: Variant = null) -> void:
	if visible:
		_refresh_results()


func _on_command_executed(_entry: Dictionary) -> void:
	_refresh_history()


func _on_history_cleared() -> void:
	_refresh_history()


func _refresh_results() -> void:
	if _registry == null:
		return
	var term := _search_term(_query.text)
	var commands := _registry.search(term, max_results)
	_command_list.clear()

	for command: NucleusDevelopmentCommand in commands:
		var index := _command_list.add_item(
			"[%s] %s" % [str(command.category), command.title]
		)
		_command_list.set_item_metadata(index, str(command.id))

	if _command_list.item_count > 0:
		_command_list.select(0)
	_update_command_detail()


func _update_command_detail() -> void:
	var command := _selected_command()
	if command == null:
		_command_title.text = "No matching command"
		_command_id.text = ""
		_description.text = "Type to search registered development commands."
		_usage.text = ""
		return

	_command_title.text = command.title
	_command_id.text = str(command.id)
	_description.text = command.description
	_usage.text = "Usage: %s" % command.usage()
	if not command.aliases.is_empty():
		_usage.text += "\nAliases: %s" % ", ".join(command.aliases)


func _execute_or_complete() -> void:
	if _registry == null:
		return
	var parsed := _registry.parse_line(_query.text)
	if bool(parsed.get("ok", false)):
		var tokens: PackedStringArray = parsed["tokens"]
		if not tokens.is_empty():
			var exact := _registry.resolve_command(tokens[0])
			if exact != null:
				if tokens.size() > 1 or _required_argument_count(exact) == 0:
					_execute_line(_query.text)
					return
				_complete_command(exact)
				return

	var command := _selected_command()
	if command != null:
		_complete_or_execute_command(command)


func _complete_or_execute_command(command: NucleusDevelopmentCommand) -> void:
	if _required_argument_count(command) > 0:
		_complete_command(command)
		return
	_execute_line(str(command.id))


func _complete_command(command: NucleusDevelopmentCommand) -> void:
	_query.text = "%s " % str(command.id)
	_query.caret_column = _query.text.length()
	_restore_query_focus()
	_update_command_detail()


func _execute_line(line: String) -> void:
	var normalized := line.strip_edges()
	if normalized.is_empty():
		return
	_registry.execute_line(
		normalized,
		{
			"source": self,
		},
	)
	if not is_inside_tree() or not is_instance_valid(_query):
		return
	_query.clear()
	_refresh_results()
	call_deferred("_restore_query_focus")


func _restore_query_focus() -> void:
	if (
		not is_inside_tree()
		or not visible
		or not is_instance_valid(_query)
		or not _query.is_inside_tree()
	):
		return
	_query.grab_focus()


func _selected_command() -> NucleusDevelopmentCommand:
	if _registry == null:
		return null
	var selected := _command_list.get_selected_items()
	if selected.is_empty():
		return null
	var id := str(_command_list.get_item_metadata(selected[0]))
	return _registry.resolve_command(id)


func _select_relative(offset: int) -> void:
	if _command_list.item_count <= 0:
		return
	var selected := _command_list.get_selected_items()
	var index := 0
	if not selected.is_empty():
		index = selected[0]
	index = clampi(index + offset, 0, _command_list.item_count - 1)
	_command_list.select(index)
	_command_list.ensure_current_is_visible()
	_update_command_detail()


func _refresh_history() -> void:
	if _registry == null:
		_output.text = "Registry unavailable."
		return
	var history := _registry.get_history()
	if history.is_empty():
		_output.text = "No commands executed yet."
		return
	var lines := PackedStringArray()
	var first := maxi(0, history.size() - history_lines)
	for index: int in range(first, history.size()):
		var entry := history[index]
		var raw_line := str(entry.get("raw_line", entry.get("command_id", "")))
		var status := str(entry.get("status", "INFO"))
		var message := str(entry.get("message", ""))
		lines.append("[%s] %s" % [status, raw_line])
		if not message.is_empty():
			lines.append(message)
	_output.text = "\n".join(lines)
	_output.scroll_to_line(maxi(0, lines.size() - 1))


func _search_term(line: String) -> String:
	var parsed := _registry.parse_line(line)
	if bool(parsed.get("ok", false)):
		var tokens: PackedStringArray = parsed["tokens"]
		if not tokens.is_empty() and _registry.resolve_command(tokens[0]) != null:
			return tokens[0]
	return line.strip_edges()


func _required_argument_count(command: NucleusDevelopmentCommand) -> int:
	var count := 0
	for argument: NucleusDevelopmentCommandArgument in command.arguments:
		if not argument.optional:
			count += 1
	return count
