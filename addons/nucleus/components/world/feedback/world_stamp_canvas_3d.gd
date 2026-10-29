extends Node2D
## Internal CanvasItem used by NucleusWorldStampViewport3D.

var renderer: NucleusWorldStampViewport3D


func _draw() -> void:
	if renderer == null:
		return

	renderer._draw_stamps(self)
