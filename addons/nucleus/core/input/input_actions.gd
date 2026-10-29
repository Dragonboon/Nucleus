class_name NucleusInputActions
extends RefCounted
## Semantic input actions included by the Nucleus template.
##
## Games are free to add or remove actions. Core systems never require these
## actions to exist; they are provided as useful, device-agnostic defaults.
##
## UI_* constants are navigation actions for active menus/dialogs. World and
## session gameplay should use semantic gameplay actions instead of interpreting
## UI_CANCEL as a universal back/leave command.

const UI_ACCEPT: StringName = &"ui_accept"
const UI_CANCEL: StringName = &"ui_cancel"

const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"

const LOOK_LEFT: StringName = &"look_left"
const LOOK_RIGHT: StringName = &"look_right"
const LOOK_UP: StringName = &"look_up"
const LOOK_DOWN: StringName = &"look_down"

const PRIMARY_ACTION: StringName = &"primary_action"
const SECONDARY_ACTION: StringName = &"secondary_action"
const INTERACT: StringName = &"interact"

## Gameplay-level pause/menu request. Prefer this over UI_CANCEL from world scenes.
const PAUSE: StringName = &"pause"
