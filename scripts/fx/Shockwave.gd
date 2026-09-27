class_name Shockwave
extends Node2D
## Expanding ring used for bomb detonations and big merges.

var radius: float = 200.0
var color: Color = Color.WHITE
var width: float = 7.0
var life: float = 0.42

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = _t / life
	var eased: float = 1.0 - pow(1.0 - k, 3.0)
	draw_arc(Vector2.ZERO, radius * eased, 0.0, TAU, 56, Color(color, (1.0 - k) * 0.9), maxf(1.0, width * (1.0 - k * 0.6)), true)
	draw_circle(Vector2.ZERO, radius * eased * 0.82, Color(color, (1.0 - k) * 0.16))
