class_name NucleusCameraImpulseEffect2D
extends NucleusActionEffect
## GameplayAction effect that submits one profile to NucleusCameraFeedback2D.

@export var feedback: NucleusCameraFeedback2D
@export var profile: NucleusCameraImpulseProfile2D
@export_range(0.0, 1000.0, 0.01, "or_greater")
var strength: float = 1.0
@export var context_strength_key: StringName


func can_apply(_context: Dictionary) -> Error:
	return (
		OK
		if feedback and profile
		else ERR_UNCONFIGURED
	)


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	var resolved_strength: float = strength

	if (
		context_strength_key != &""
		and context.has(context_strength_key)
	):
		resolved_strength *= maxf(
			0.0,
			float(context[context_strength_key]),
		)

	return feedback.play_impulse(
		profile,
		resolved_strength,
	)
