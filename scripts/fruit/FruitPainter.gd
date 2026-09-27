class_name FruitPainter
extends Node2D
## Throwaway node used as the drawing surface for FruitArt's bake step.
## Never enters the game scene — FruitArt parents it to an offscreen
## SubViewport, grabs the pixels, then frees it.

var tier_id: int = 0
var radius: float = 20.0

func _draw() -> void:
	FruitArt.paint(self, tier_id, radius)
