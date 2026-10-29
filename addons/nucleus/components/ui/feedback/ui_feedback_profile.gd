class_name NucleusUIFeedbackProfile
extends Resource
## Visual and audio feedback policy for one interactive Control.
##
## New integrations should prefer the optional visual-state Resources. Legacy
## scale/opacity exports remain as a compact fallback for existing scenes.

@export var motion: NucleusUIMotionProfile

@export_group("Visual states")
@export var idle_state: NucleusUIVisualStateProfile
@export var hover_state: NucleusUIVisualStateProfile
@export var focus_state: NucleusUIVisualStateProfile
@export var pressed_state: NucleusUIVisualStateProfile
@export var selected_state: NucleusUIVisualStateProfile

@export_group("Legacy scale fallback")
@export var use_scale: bool = true
@export_range(0.1, 3.0, 0.001)
var hover_scale: float = 1.025
@export_range(0.1, 3.0, 0.001)
var focus_scale: float = 1.035
@export_range(0.1, 3.0, 0.001)
var pressed_scale: float = 0.97
@export var disable_scale_with_reduced_motion: bool = true

@export_group("Legacy opacity fallback")
@export var use_opacity: bool = false
@export_range(0.0, 1.0, 0.01)
var idle_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01)
var active_alpha: float = 1.0
@export_range(0.0, 1.0, 0.01)
var pressed_alpha: float = 0.92

@export_group("Audio")
@export var hover_cue: NucleusAudioCue
@export var focus_cue: NucleusAudioCue
@export var pressed_cue: NucleusAudioCue
