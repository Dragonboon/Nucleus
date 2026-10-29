class_name NucleusAudioCueEffect
extends NucleusActionEffect
## Plays an existing non-positional NucleusAudioCue on action commit.

@export var cue: NucleusAudioCue


func can_apply(_context: Dictionary) -> Error:
	if cue == null or cue.stream == null:
		return ERR_UNCONFIGURED

	return OK


func apply(context: Dictionary) -> Error:
	var error: Error = can_apply(context)

	if error != OK:
		return error

	var player: AudioStreamPlayer = NucleusAudio.play_cue(cue)

	return OK if player else ERR_CANT_CREATE
