class_name NucleusInputGlyphEntry
extends Resource
## One game-owned glyph mapping used by [NucleusInputGlyphProfile].
##
## Use [method NucleusInputGlyphProfile.event_key] to obtain stable keys from
## the InputEvents that Nucleus Input already exposes.

@export var event_key: StringName
@export var texture: Texture2D
