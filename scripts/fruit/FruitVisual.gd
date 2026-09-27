class_name FruitVisual
extends Node2D
## Non-physics fruit used for the "currently aiming" drop preview, plus the
## dashed guide line showing where it will fall. Kept separate from Fruit.gd
## so the preview never touches physics.

@export var radius: float = 20.0
@export var color: Color = Color.WHITE
@export var guide_length: float = 260.0
@export var tier_id: int = 0

var _ghosted: bool = false


func set_tier(new_tier: int) -> void:
	tier_id = new_tier
	var data := FruitDatabase.get_tier(new_tier)
	if data == null:
		return
	radius = data.radius
	color = data.color
	queue_redraw()


## Dims the preview when the aim is over the trash bin.
func set_ghosted(on: bool) -> void:
	if _ghosted == on:
		return
	_ghosted = on
	queue_redraw()


func _draw() -> void:
	var alpha: float = 0.35 if _ghosted else 0.92
	var tex := FruitArt.get_texture(tier_id)
	var half := FruitArt.get_half_size(tier_id)
	if tex != null and half > 0.0:
		modulate = Color(1, 1, 1, alpha)
		draw_texture_rect(tex, Rect2(-Vector2.ONE * half, Vector2.ONE * half * 2.0), false)
	else:
		modulate = Color(1, 1, 1, 1)
		draw_circle(Vector2.ZERO, radius, Color(color, alpha))
	if guide_length > 0.0:
		var y := radius + 6.0
		var dash := 12.0
		var gap := 10.0
		var yy := y
		while yy < guide_length:
			draw_line(Vector2(0, yy), Vector2(0, minf(yy + dash, guide_length)), Color(0.25, 0.27, 0.34, 0.22), 4.0)
			yy += dash + gap
