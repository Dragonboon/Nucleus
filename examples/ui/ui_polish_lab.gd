extends Control
## Manual acceptance lab for reusable Nucleus UI primitives.
##
## The lab intentionally composes existing components instead of inventing a
## parallel demo framework. Each page validates a small ownership boundary.

const HIGH_CONTRAST_THEME: Theme = preload(
	"res://addons/nucleus/components/ui/theme/nucleus_high_contrast_theme.tres"
)

const TOAST_HOST_SCENE: PackedScene = preload(
	"res://addons/nucleus/components/ui/toast/ui_toast_host.tscn"
)
const MODAL_HOST_SCENE: PackedScene = preload(
	"res://addons/nucleus/components/ui/modal/ui_modal_host.tscn"
)
const SCREEN_EFFECTS_SCENE: PackedScene = preload(
	"res://addons/nucleus/components/ui/effects/ui_screen_effects.tscn"
)

var _page_controller: NucleusUIPageController
var _pages: Array[Control] = []
var _tab_buttons: Array[BaseButton] = []

var _presenter: NucleusUIPresenter
var _progress: NucleusUIProgressFeedback
var _animated_value: NucleusUIAnimatedValue
var _shader_effect: NucleusUIShaderEffect
var _typewriter: NucleusUITypewriter
var _typewriter_status: Label
var _typewriter_reduced_motion: CheckButton
var _typewriter_was_skipped: bool = false
var _typewriter_has_started: bool = false

var _toast_host: NucleusUIToastHost
var _modal_host: NucleusUIModalHost
var _screen_effects: NucleusUIScreenEffects
var _demo_modal: NucleusUIModal
var _modal_status: Label

var _breakpoints: NucleusUIBreakpoints
var _breakpoint_status: Label
var _accessibility_button: Button
var _accessibility_status: Label
var _input_focus_scope: NucleusUIFocusScope
var _hold_status: Label

var _panel_visible: bool = true
var _theme_status: Label
var _health: float = 100.0
var _score: float = 250.0
var _toast_index: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_global_components()
	_build_lab()
	call_deferred("_finish_initialization")


func _setup_global_components() -> void:
	_toast_host = TOAST_HOST_SCENE.instantiate() as NucleusUIToastHost
	add_child(_toast_host)

	_modal_host = MODAL_HOST_SCENE.instantiate() as NucleusUIModalHost
	add_child(_modal_host)
	_build_demo_modal()

	_screen_effects = (
		SCREEN_EFFECTS_SCENE.instantiate()
		as NucleusUIScreenEffects
	)
	add_child(_screen_effects)

	_breakpoints = NucleusUIBreakpoints.new()
	_breakpoints.breakpoint_changed.connect(_on_breakpoint_changed)
	add_child(_breakpoints)


func _build_lab() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.045, 0.052, 0.068, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 24)
	margin.add_theme_constant_override(&"margin_top", 20)
	margin.add_theme_constant_override(&"margin_right", 24)
	margin.add_theme_constant_override(&"margin_bottom", 20)
	add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override(&"separation", 12)
	margin.add_child(root_box)

	_build_header(root_box)

	var tab_bar := HFlowContainer.new()
	tab_bar.add_theme_constant_override(&"separation", 8)
	root_box.add_child(tab_bar)

	var page_host := Control.new()
	page_host.custom_minimum_size = Vector2(0.0, 320.0)
	page_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(page_host)

	var theme_page := _create_page(page_host, tab_bar, "Theme & Controls")
	var theme_focus := _build_theme_page(theme_page)
	_attach_focus_scope(theme_page, theme_focus)

	var motion_page := _create_page(page_host, tab_bar, "Motion & Feedback")
	var motion_focus := _build_motion_feedback_page(motion_page)
	_attach_focus_scope(motion_page, motion_focus)

	var input_page := _create_page(page_host, tab_bar, "Input & Focus")
	var input_focus := _build_input_focus_page(input_page)
	_input_focus_scope = _attach_focus_scope(input_page, input_focus)

	var text_page := _create_page(page_host, tab_bar, "Text & State")
	var text_focus := _build_text_state_page(text_page)
	_attach_focus_scope(text_page, text_focus)

	var overlay_page := _create_page(page_host, tab_bar, "Overlays & Layout")
	var overlay_focus := _build_overlays_layout_page(overlay_page)
	_attach_focus_scope(overlay_page, overlay_focus)

	_page_controller = NucleusUIPageController.new()
	_page_controller.pages = _pages
	_page_controller.tab_buttons = _tab_buttons
	_page_controller.initial_index = 0
	_page_controller.animate_transitions = true
	_page_controller.page_changed.connect(_on_lab_page_changed)
	add_child(_page_controller)


func _build_header(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Nucleus UI Acceptance Lab"
	title.add_theme_font_size_override(&"font_size", 28)
	parent.add_child(title)

	var subtitle := Label.new()
	subtitle.text = (
		"Exercises existing scene-owned UI primitives with mouse, keyboard "
		+ "and controller. Tabs use NucleusUIPageController; pages restore "
		+ "focus through NucleusUIFocusScope."
	)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(subtitle)


func _create_page(
	page_host: Control,
	tab_bar: HFlowContainer,
	title: String,
) -> Control:
	var page := Control.new()
	page.name = title.replace(" ", "").replace("&", "")
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_host.add_child(page)
	_pages.append(page)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(scroll)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.custom_minimum_size.x = 0.0
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(&"margin_left", 4)
	margin.add_theme_constant_override(&"margin_top", 4)
	margin.add_theme_constant_override(&"margin_right", 16)
	margin.add_theme_constant_override(&"margin_bottom", 20)
	scroll.add_child(margin)

	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 14)
	margin.add_child(body)

	var tab := Button.new()
	tab.text = title
	tab.toggle_mode = true
	tab.focus_mode = Control.FOCUS_ALL
	tab_bar.add_child(tab)
	_tab_buttons.append(tab)

	return page


func _page_body(page: Control) -> VBoxContainer:
	return page.get_node("Scroll/Margin/Body") as VBoxContainer


func _add_section(
	parent: VBoxContainer,
	title: String,
	description: String = "",
) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 16)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 16)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 8)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override(&"font_size", 18)
	content.add_child(heading)

	if not description.is_empty():
		var detail := Label.new()
		detail.text = description
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(detail)

	return content


func _attach_focus_scope(
	page: Control,
	initial_focus: Control,
) -> NucleusUIFocusScope:
	var scope := NucleusUIFocusScope.new()
	scope.target = page
	scope.initial_focus = initial_focus
	scope.focus_on_ready = false
	scope.focus_when_shown = true
	scope.restore_last_focus = true
	page.add_child(scope)
	return scope


func _build_theme_page(page: Control) -> Control:
	var body := _page_body(page)
	var section := _add_section(
		body,
		"Native controls and accessible theme",
		"Local contrast preview: no changes to project-wide Theme resources.",
	)
	var contrast := CheckButton.new()
	contrast.text = "High-contrast preview"
	contrast.toggled.connect(_on_theme_contrast_changed)
	section.add_child(contrast)
	var sample := Button.new()
	sample.text = "Button: hover / focus / activate"
	section.add_child(sample)
	var unavailable := Button.new()
	unavailable.text = "Disabled action"
	unavailable.disabled = true
	section.add_child(unavailable)
	var edit := LineEdit.new()
	edit.placeholder_text = "Enter text to verify caret and focus"
	section.add_child(edit)
	var selection := OptionButton.new()
	selection.add_item("First option")
	selection.add_item("Second option")
	section.add_child(selection)
	var checkbox := CheckBox.new()
	checkbox.text = "Native checkbox"
	section.add_child(checkbox)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 50.0
	section.add_child(slider)
	var progress := ProgressBar.new()
	progress.value = 65.0
	section.add_child(progress)
	_theme_status = Label.new()
	_theme_status.text = "Test Tab, Shift+Tab, mouse, controller and resizing."
	_theme_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_theme_status)
	sample.pressed.connect(
		func() -> void: _theme_status.text = "Button activated."
	)
	return contrast


func _on_theme_contrast_changed(is_enabled: bool) -> void:
	theme = HIGH_CONTRAST_THEME if is_enabled else null
	if _theme_status != null:
		_theme_status.text = (
			"High contrast enabled locally."
			if is_enabled else "Project default theme restored."
	)


func _build_motion_feedback_page(page: Control) -> Control:
	var body := _page_body(page)
	var first_focus := _build_presenter_demo(body)
	_build_interaction_demo(body)
	_build_progress_demo(body)
	_build_animated_value_demo(body)
	_build_shader_demo(body)
	return first_focus


func _build_presenter_demo(parent: VBoxContainer) -> Button:
	var section := _add_section(
		parent,
		"Declarative presentation",
		"NucleusUIPresenter owns only PresentationRoot transforms; layout stays "
		+ "outside that root.",
	)

	var slot := Control.new()
	slot.custom_minimum_size = Vector2(560.0, 118.0)
	section.add_child(slot)

	var panel := PanelContainer.new()
	panel.position = Vector2(0.0, 6.0)
	panel.size = Vector2(540.0, 92.0)
	slot.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	panel.add_child(margin)

	var label := Label.new()
	label.text = "Slide/fade transition with authored layout left untouched."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)

	_presenter = NucleusUIPresenter.new()
	_presenter.target = panel
	_presenter.transition = NucleusUITransitionProfile.slide(
		Vector2(0.0, 24.0),
		0.22,
		true,
	)
	slot.add_child(_presenter)

	var toggle := Button.new()
	toggle.text = "Hide / show panel"
	toggle.pressed.connect(_toggle_panel)
	section.add_child(toggle)
	return toggle


func _build_interaction_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Interaction visual states",
		"Hover, focus, press and selected state remain additive presentation.",
	)

	var button := Button.new()
	button.text = "Hover / focus / press / toggle"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(340.0, 46.0)
	section.add_child(button)

	var profile := NucleusUIFeedbackProfile.new()
	profile.motion = NucleusUIMotionProfile.new()
	profile.motion.duration = 0.1
	profile.motion.reduced_motion_scale = 0.25

	var hover := NucleusUIVisualStateProfile.new()
	hover.scale_multiplier = Vector2(1.025, 1.025)

	var focus := NucleusUIVisualStateProfile.new()
	focus.scale_multiplier = Vector2(1.04, 1.04)

	var pressed := NucleusUIVisualStateProfile.new()
	pressed.scale_multiplier = Vector2(0.97, 0.97)

	var selected := NucleusUIVisualStateProfile.new()
	selected.scale_multiplier = Vector2(1.02, 1.02)
	selected.alpha_multiplier = 0.92

	profile.hover_state = hover
	profile.focus_state = focus
	profile.pressed_state = pressed
	profile.selected_state = selected

	var feedback := NucleusUIInteractionFeedback.new()
	feedback.target = button
	feedback.profile = profile
	section.add_child(feedback)


func _build_progress_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Progress feedback",
		"Primary and delayed trailing ranges demonstrate reusable HUD response.",
	)

	var slot := Control.new()
	slot.custom_minimum_size = Vector2(560.0, 34.0)
	section.add_child(slot)

	var trailing := ProgressBar.new()
	trailing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trailing.show_percentage = false
	trailing.value = _health
	trailing.modulate = Color(1.0, 0.45, 0.45, 0.55)
	slot.add_child(trailing)

	var primary := ProgressBar.new()
	primary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	primary.show_percentage = true
	primary.value = _health
	slot.add_child(primary)

	_progress = NucleusUIProgressFeedback.new()
	_progress.primary_target = primary
	_progress.trailing_target = trailing
	_progress.feedback_target = slot
	_progress.decrease_trail_delay = 0.22
	_progress.pulse_on_decrease = true
	_progress.pulse_on_increase = false
	slot.add_child(_progress)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)
	section.add_child(actions)

	var damage := Button.new()
	damage.text = "Damage -25"
	damage.pressed.connect(_change_health.bind(-25.0))
	actions.add_child(damage)

	var heal := Button.new()
	heal.text = "Heal +15"
	heal.pressed.connect(_change_health.bind(15.0))
	actions.add_child(heal)

	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(_reset_health)
	actions.add_child(reset)


func _build_animated_value_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Animated numeric value",
		"NucleusUIAnimatedValue keeps a Label and Range synchronized.",
	)

	var value_label := Label.new()
	value_label.text = "Score: 250"
	value_label.add_theme_font_size_override(&"font_size", 20)
	section.add_child(value_label)

	var value_bar := ProgressBar.new()
	value_bar.min_value = 0.0
	value_bar.max_value = 1000.0
	value_bar.value = _score
	value_bar.show_percentage = false
	section.add_child(value_bar)

	_animated_value = NucleusUIAnimatedValue.new()
	_animated_value.range_target = value_bar
	_animated_value.label_target = value_label
	_animated_value.decimals = 0
	_animated_value.text_template = "Score: {value}"
	section.add_child(_animated_value)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)
	section.add_child(actions)

	var add_score := Button.new()
	add_score.text = "Add 125"
	add_score.pressed.connect(_add_score)
	actions.add_child(add_score)

	var reset_score := Button.new()
	reset_score.text = "Reset score"
	reset_score.pressed.connect(_reset_score)
	actions.add_child(reset_score)


func _build_shader_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Game-owned shader parameter",
		"Nucleus animates an allowed parameter; the shader remains game-owned.",
	)

	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(560.0, 46.0)
	section.add_child(rect)

	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform float intensity : hint_range(0.0, 1.0) = 0.0;\n"
		+ "void fragment() {\n"
		+ "\tCOLOR = vec4(0.12 + intensity * 0.35, 0.28, 0.62, 1.0);\n"
		+ "}\n"
	)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	rect.material = shader_material

	_shader_effect = NucleusUIShaderEffect.new()
	_shader_effect.target = rect
	rect.add_child(_shader_effect)

	var pulse := Button.new()
	pulse.text = "Animate shader intensity"
	pulse.pressed.connect(_pulse_shader)
	section.add_child(pulse)


func _build_input_focus_page(page: Control) -> Control:
	var body := _page_body(page)
	_build_glyph_demo(body)
	var hold_button := _build_hold_demo(body)
	_build_accessibility_tooltip_demo(body)
	_build_focus_demo(body)
	return hold_button


func _build_glyph_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Input glyph with fallback",
		"The binding follows active source/family and retains readable text.",
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	section.add_child(row)

	var glyph := TextureRect.new()
	glyph.custom_minimum_size = Vector2(32.0, 32.0)
	glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(glyph)

	var fallback := Label.new()
	fallback.text = "Binding"
	row.add_child(fallback)

	var profile := NucleusInputGlyphProfile.new()
	_add_demo_glyphs(profile, NucleusInputTypes.Source.KEYBOARD_MOUSE)
	_add_demo_glyphs(profile, NucleusInputTypes.Source.GAMEPAD)

	var binding := NucleusInputGlyphBinding.new()
	binding.action = &"ui_accept"
	binding.profile = profile
	binding.glyph_target = glyph
	binding.fallback_label = fallback
	row.add_child(binding)


func _build_hold_demo(parent: VBoxContainer) -> Button:
	var section := _add_section(
		parent,
		"Hold to confirm",
		"Hold the button until the progress bar completes; releasing cancels.",
	)

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.value = 0.0
	progress.show_percentage = false
	section.add_child(progress)

	var button := Button.new()
	button.text = "Hold to confirm action"
	section.add_child(button)

	_hold_status = Label.new()
	_hold_status.text = "Waiting for hold input."
	section.add_child(_hold_status)

	var hold := NucleusUIHoldToConfirm.new()
	hold.target = button
	hold.progress_target = progress
	hold.hold_duration = 0.8
	hold.confirmed.connect(_on_hold_confirmed)
	hold.canceled.connect(_on_hold_canceled)
	section.add_child(hold)
	return button


func _build_accessibility_tooltip_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Tooltip + accessibility metadata",
		"Hover for the native tooltip. Metadata mirrors readable fallback text.",
	)

	_accessibility_button = Button.new()
	_accessibility_button.text = "Hover / focus for metadata"
	section.add_child(_accessibility_button)

	var tooltip := NucleusUITooltipBinding.new()
	tooltip.target = _accessibility_button
	tooltip.fallback_text = "Native tooltip owned by Godot Theme and Control."
	_accessibility_button.add_child(tooltip)

	var metadata := NucleusUIAccessibilityMetadata.new()
	metadata.target = _accessibility_button
	metadata.fallback_name = "UI acceptance metadata button"
	metadata.fallback_description = (
		"Demonstrates translated accessibility metadata without replacing "
		+ "Godot's accessibility tree."
	)
	_accessibility_button.add_child(metadata)

	_accessibility_status = Label.new()
	_accessibility_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_accessibility_status)


func _build_focus_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Focus scope",
		"Switch tabs and return. The page restores the last valid focus owner.",
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	section.add_child(row)

	for index in range(3):
		var button := Button.new()
		button.text = "Focus target %d" % (index + 1)
		row.add_child(button)

	var restore := Button.new()
	restore.text = "Release then restore page focus"
	restore.pressed.connect(_release_and_restore_focus)
	section.add_child(restore)


func _build_text_state_page(page: Control) -> Control:
	var body := _page_body(page)
	var replay := _build_typewriter_demo(body)
	_build_page_controller_info(body)
	return replay


func _build_typewriter_demo(parent: VBoxContainer) -> Button:
	var section := _add_section(
		parent,
		"RichTextLabel typewriter",
		"Replay and skip use explicit lab handlers. The status line exposes "
		+ "whether reduced-motion policy completed the reveal immediately.",
	)

	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(560.0, 108.0)
	text.bbcode_enabled = true
	text.fit_content = false
	text.text = (
		"[b]Nucleus[/b] reveals parsed text progressively, pauses at "
		+ "punctuation, and keeps dialogue ownership outside the component. "
		+ "Replay should restart from zero; Skip should expose the remainder."
	)
	section.add_child(text)

	_typewriter = NucleusUITypewriter.new()
	_typewriter.target = text
	_typewriter.characters_per_second = 24.0
	_typewriter.minor_punctuation_delay = 0.1
	_typewriter.major_punctuation_delay = 0.24
	_typewriter.respect_reduced_motion = false
	_typewriter.reveal_started.connect(_on_typewriter_started)
	_typewriter.progress_changed.connect(_on_typewriter_progress)
	_typewriter.reveal_finished.connect(_on_typewriter_finished)
	_typewriter.skipped.connect(_on_typewriter_skipped)
	text.add_child(_typewriter)

	_typewriter_status = Label.new()
	_typewriter_status.text = "Typewriter awaiting initial replay."
	_typewriter_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_typewriter_status)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)
	section.add_child(actions)

	var replay := Button.new()
	replay.text = "Replay from start"
	replay.pressed.connect(_on_typewriter_replay_pressed)
	actions.add_child(replay)

	var skip := Button.new()
	skip.text = "Skip to end"
	skip.pressed.connect(_on_typewriter_skip_pressed)
	actions.add_child(skip)

	var reset := Button.new()
	reset.text = "Reset hidden"
	reset.pressed.connect(_on_typewriter_reset_pressed)
	actions.add_child(reset)

	_typewriter_reduced_motion = CheckButton.new()
	_typewriter_reduced_motion.text = "Respect shared reduced-motion policy"
	_typewriter_reduced_motion.button_pressed = false
	_typewriter_reduced_motion.toggled.connect(
		_on_typewriter_reduced_motion_toggled
	)
	section.add_child(_typewriter_reduced_motion)

	return replay


func _build_page_controller_info(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Page controller exercised by this lab",
		"The four top tabs are not custom lab navigation. They are the "
		+ "production NucleusUIPageController with toggle buttons and focus "
		+ "restoration.",
	)

	var note := Label.new()
	note.text = (
		"Switch repeatedly between pages with mouse and keyboard/controller. "
		+ "Animated page fades should not leave stale visibility or focus."
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(note)


func _build_overlays_layout_page(page: Control) -> Control:
	var body := _page_body(page)
	var first_focus := _build_toast_demo(body)
	_build_modal_demo(body)
	_build_screen_effects_demo(body)
	_build_responsive_demo(body)
	_build_safe_area_demo(body)
	return first_focus


func _build_toast_demo(parent: VBoxContainer) -> Button:
	var section := _add_section(
		parent,
		"Toast host",
		"Scene-owned queue, priority and dedupe behavior with generated Controls.",
	)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)
	section.add_child(actions)

	var show_toast := Button.new()
	show_toast.text = "Show toast"
	show_toast.pressed.connect(_show_toast)
	actions.add_child(show_toast)

	var priority := Button.new()
	priority.text = "Priority toast"
	priority.pressed.connect(_show_priority_toast)
	actions.add_child(priority)

	var clear := Button.new()
	clear.text = "Clear toasts"
	clear.pressed.connect(_clear_toasts)
	actions.add_child(clear)
	return show_toast


func _build_modal_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Modal + dialog composition",
		"The host owns stack/backdrop policy; modal owns presentation/focus; "
		+ "dialog owns text and buttons.",
	)

	var open_modal := Button.new()
	open_modal.text = "Open modal dialog"
	open_modal.pressed.connect(_open_demo_modal)
	section.add_child(open_modal)

	_modal_status = Label.new()
	_modal_status.text = "Modal has not been opened yet."
	section.add_child(_modal_status)


func _build_screen_effects_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Screen effects",
		"Fade/flash remain scene-owned visual presentation, not gameplay state.",
	)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)
	section.add_child(actions)

	var flash := Button.new()
	flash.text = "Flash"
	flash.pressed.connect(_flash_screen)
	actions.add_child(flash)

	var cover := Button.new()
	cover.text = "Cover + reveal"
	cover.pressed.connect(_cover_and_reveal)
	actions.add_child(cover)


func _build_responsive_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Responsive breakpoints",
		"Resize the viewport to validate compact/regular/wide classification.",
	)

	_breakpoint_status = Label.new()
	section.add_child(_breakpoint_status)

	var wide_marker := Label.new()
	wide_marker.text = "This marker is hidden in COMPACT mode."
	section.add_child(wide_marker)

	var visibility := NucleusUIResponsiveVisibility.new()
	visibility.target = wide_marker
	visibility.breakpoints = _breakpoints
	visibility.visible_compact = false
	visibility.visible_regular = true
	visibility.visible_wide = true
	wide_marker.add_child(visibility)


func _build_safe_area_demo(parent: VBoxContainer) -> void:
	var section := _add_section(
		parent,
		"Safe-area inset",
		"A deterministic fallback inset demonstrates the component on desktop.",
	)

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(560.0, 92.0)
	section.add_child(frame)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.16, 0.18, 0.23, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(background)

	var inset := PanelContainer.new()
	frame.add_child(inset)

	var label := Label.new()
	label.text = "Fallback safe area: 18 px horizontal / 10 px vertical"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inset.add_child(label)

	var safe_area := NucleusUISafeArea.new()
	safe_area.target = inset
	safe_area.use_native_safe_area = false
	safe_area.fallback_margins = Vector4(18.0, 10.0, 18.0, 10.0)
	frame.add_child(safe_area)


func _build_demo_modal() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_host.get_content().add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480.0, 220.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 22)
	margin.add_theme_constant_override(&"margin_top", 18)
	margin.add_theme_constant_override(&"margin_right", 22)
	margin.add_theme_constant_override(&"margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 10)
	margin.add_child(content)

	var title := Label.new()
	title.add_theme_font_size_override(&"font_size", 20)
	content.add_child(title)

	var message := Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override(&"separation", 8)
	content.add_child(actions)

	var cancel := Button.new()
	cancel.text = "Cancel"
	actions.add_child(cancel)

	var confirm := Button.new()
	confirm.text = "Confirm"
	actions.add_child(confirm)

	var presenter := NucleusUIPresenter.new()
	presenter.target = panel
	presenter.transition = NucleusUITransitionProfile.pop(
		0.16,
		Vector2(0.96, 0.96),
	)
	panel.add_child(presenter)

	var focus_scope := NucleusUIFocusScope.new()
	focus_scope.target = panel
	focus_scope.initial_focus = confirm
	focus_scope.focus_on_ready = false
	panel.add_child(focus_scope)

	_demo_modal = NucleusUIModal.new()
	_demo_modal.target = panel
	_demo_modal.presenter = presenter
	_demo_modal.focus_scope = focus_scope
	_demo_modal.dismiss_on_backdrop = true
	panel.add_child(_demo_modal)

	var dialog := NucleusUIDialog.new()
	dialog.modal = _demo_modal
	dialog.title_label = title
	dialog.message_label = message
	dialog.confirm_button = confirm
	dialog.cancel_button = cancel
	dialog.fallback_title = "Nucleus modal composition"
	dialog.fallback_message = (
		"Accept, cancel, click the backdrop, or press ui_cancel. Focus should "
		+ "return to the control that opened the modal."
	)
	dialog.fallback_confirm_text = "Accept"
	dialog.fallback_cancel_text = "Cancel"
	dialog.confirmed.connect(_on_demo_modal_confirmed)
	dialog.canceled.connect(_on_demo_modal_canceled)
	panel.add_child(dialog)


func _finish_initialization() -> void:
	_refresh_accessibility_status()
	_refresh_breakpoint_status()


func _toggle_panel() -> void:
	_panel_visible = not _panel_visible

	if _panel_visible:
		_presenter.show_animated()
	else:
		_presenter.hide_animated()


func _change_health(delta: float) -> void:
	_health = clampf(_health + delta, 0.0, 100.0)
	_progress.set_value(_health)


func _reset_health() -> void:
	_health = 100.0
	_progress.set_value(_health)


func _add_score() -> void:
	_score += 125.0

	if _score > 1000.0:
		_score = 0.0

	_animated_value.set_value(_score)


func _reset_score() -> void:
	_score = 250.0
	_animated_value.set_value(_score)


func _pulse_shader() -> void:
	var tween := _shader_effect.animate_parameter(
		&"intensity",
		1.0,
		0.65,
	)

	if tween:
		tween.finished.connect(_restore_shader_intensity)


func _restore_shader_intensity() -> void:
	_shader_effect.animate_parameter(
		&"intensity",
		0.0,
		1.0,
	)


func _release_and_restore_focus() -> void:
	if _input_focus_scope == null:
		return

	_input_focus_scope.release_focus()
	_input_focus_scope.call_deferred("restore_focus")


func _on_lab_page_changed(
	index: int,
	_page: Control,
) -> void:
	if index == 2 and not _typewriter_has_started:
		_on_typewriter_replay_pressed()


func _on_hold_confirmed() -> void:
	if _hold_status:
		_hold_status.text = "Confirmed. Hold semantics completed."


func _on_hold_canceled() -> void:
	if _hold_status:
		_hold_status.text = "Canceled before confirmation."


func _refresh_accessibility_status() -> void:
	if _accessibility_button == null or _accessibility_status == null:
		return

	_accessibility_status.text = (
		"accessibility_name: %s\naccessibility_description: %s"
		% [
			_accessibility_button.accessibility_name,
			_accessibility_button.accessibility_description,
		]
	)


func _on_typewriter_replay_pressed() -> void:
	_typewriter_was_skipped = false
	_typewriter_has_started = true

	if _typewriter == null:
		return

	var error := _typewriter.restart()

	if error != OK and _typewriter_status:
		_typewriter_status.text = "Replay failed with Error %d." % error


func _on_typewriter_skip_pressed() -> void:
	if _typewriter:
		_typewriter.skip()


func _on_typewriter_reset_pressed() -> void:
	_typewriter_was_skipped = false

	if _typewriter == null:
		return

	var error := _typewriter.reset()

	if error == OK and _typewriter_status:
		_typewriter_status.text = "Reset: text hidden and ready to replay."


func _on_typewriter_reduced_motion_toggled(enabled: bool) -> void:
	if _typewriter == null:
		return

	_typewriter.respect_reduced_motion = enabled
	_on_typewriter_replay_pressed()


func _on_typewriter_started(total_characters: int) -> void:
	if _typewriter_status == null:
		return

	var policy_enabled := NucleusMotionPolicy.is_reduced_motion_enabled()
	_typewriter_status.text = (
		"Started: 0 / %d | component respects policy: %s | shared policy: %s"
		% [
			total_characters,
			str(_typewriter.respect_reduced_motion),
			str(policy_enabled),
		]
	)


func _on_typewriter_progress(
	visible_characters: int,
	total_characters: int,
) -> void:
	if _typewriter_status == null:
		return

	_typewriter_status.text = (
		"Revealing: %d / %d | progress %.0f%%"
		% [
			visible_characters,
			total_characters,
			_typewriter.get_progress() * 100.0,
		]
	)


func _on_typewriter_finished() -> void:
	if _typewriter_status == null:
		return

	if _typewriter_was_skipped:
		_typewriter_status.text = "Skipped: remaining text exposed immediately."
		_typewriter_was_skipped = false
		return

	if _typewriter_reduced_motion.button_pressed:
		_typewriter_status.text = (
			"Finished. If this was instant, inspect the shared reduced-motion "
			+ "policy shown by Replay."
		)
	else:
		_typewriter_status.text = "Finished normally. Replay should restart at 0."


func _on_typewriter_skipped() -> void:
	_typewriter_was_skipped = true


func _show_toast() -> void:
	_toast_index += 1
	_toast_host.enqueue(
		"Toast request #%d from the acceptance lab." % _toast_index,
		"Nucleus UI",
		2.5,
	)


func _show_priority_toast() -> void:
	_toast_index += 1
	_toast_host.enqueue(
		"Priority toast #%d should move ahead of pending normal items."
		% _toast_index,
		"Priority",
		3.0,
		&"lab_priority",
		10,
	)


func _clear_toasts() -> void:
	_toast_host.clear()


func _open_demo_modal() -> void:
	var error := _modal_host.open(_demo_modal)

	if _modal_status:
		_modal_status.text = (
			"Modal opened."
			if error == OK
			else "Modal open returned Error %d." % error
		)


func _on_demo_modal_confirmed() -> void:
	if _modal_status:
		_modal_status.text = "Modal accepted."


func _on_demo_modal_canceled() -> void:
	if _modal_status:
		_modal_status.text = "Modal canceled by its Cancel button."


func _flash_screen() -> void:
	_screen_effects.flash(
		Color(0.85, 0.95, 1.0, 0.7),
		0.65,
	)


func _cover_and_reveal() -> void:
	_screen_effects.cover_and_reveal(
		Color(0.02, 0.03, 0.05, 1.0),
		0.12,
	)


func _on_breakpoint_changed(
	_size_class: int,
	_is_portrait: bool,
) -> void:
	_refresh_breakpoint_status()


func _refresh_breakpoint_status() -> void:
	if _breakpoints == null or _breakpoint_status == null:
		return

	var size_name := "REGULAR"

	match _breakpoints.size_class:
		NucleusUIBreakpoints.SizeClass.COMPACT:
			size_name = "COMPACT"
		NucleusUIBreakpoints.SizeClass.WIDE:
			size_name = "WIDE"

	_breakpoint_status.text = (
		"Current class: %s | orientation: %s"
		% [
			size_name,
			"portrait" if _breakpoints.is_portrait else "landscape",
		]
	)


func _add_demo_glyphs(
	profile: NucleusInputGlyphProfile,
	source: int,
) -> void:
	var events: Array[InputEvent] = NucleusInput.get_action_events(
		&"ui_accept",
		source,
	)

	if events.is_empty():
		return

	var entry := NucleusInputGlyphEntry.new()
	entry.event_key = NucleusInputGlyphProfile.event_key(events[0])
	entry.texture = _make_demo_texture(
		Color(0.85, 0.9, 1.0, 1.0)
	)

	if source == NucleusInputTypes.Source.GAMEPAD:
		profile.generic_gamepad.append(entry)
	else:
		profile.keyboard_mouse.append(entry)


func _make_demo_texture(color: Color) -> Texture2D:
	var image := Image.create_empty(
		24,
		24,
		false,
		Image.FORMAT_RGBA8,
	)
	image.fill(color)
	return ImageTexture.create_from_image(image)
