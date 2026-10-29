class_name NucleusUIMotionProfile
extends Resource
## Reusable timing policy for UI tweens.
##
## [member reduced_motion_scale] is the retained fraction of nonessential UI
## motion when reduced motion is enabled. A value of 0 preserves Nucleus' former
## instant-transition behavior; a value above 0 keeps a smaller, faster cue.

@export_range(0.0, 10.0, 0.01, "or_greater")
var duration: float = 0.18

@export var transition: Tween.TransitionType = Tween.TRANS_QUART
@export var easing: Tween.EaseType = Tween.EASE_OUT

@export var ignore_time_scale: bool = true
@export var respect_reduced_motion: bool = true

@export_range(0.0, 1.0, 0.05)
var reduced_motion_scale: float = 0.0
