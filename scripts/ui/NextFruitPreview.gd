class_name NextFruitPreview
extends Control
## Draws a scaled-down fruit representing the next drop, clamped so large
## tiers don't blow up the UI.

@export var max_display_radius: float = 44.0

var tier_id: int = 0

func set_tier(new_tier: int) -> void:
	tier_id = new_tier
	queue_redraw()

func _draw() -> void:
	var data := FruitDatabase.get_tier(tier_id)
	if data == null:
		return
	var target: float = minf(data.radius, max_display_radius)
	var center := size * 0.5
	var tex := FruitArt.get_texture(tier_id)
	var half := FruitArt.get_half_size(tier_id)
	if tex != null and half > 0.0:
		var scale: float = target / data.radius
		var draw_half: float = half * scale
		draw_texture_rect(tex, Rect2(center - Vector2.ONE * draw_half, Vector2.ONE * draw_half * 2.0), false)
	else:
		draw_circle(center, target, data.color)
		draw_arc(center, target, 0.0, TAU, 32, data.color.darkened(0.35), 2.0, true)
