class_name FloatingText
extends Node2D
## Score / combo text that rises and fades out where the event happened.

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 30
var rise: float = 58.0
var life: float = 0.9

var _t: float = 0.0
var _drift: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_drift = _rng.randf_range(-22.0, 22.0)


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = _t / life
	var alpha: float = 1.0 - k * k
	var font := ThemeDB.fallback_font
	var baseline := Vector2(_drift * k, -rise * k - font_size * 0.4)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, alpha * 0.65))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, alpha))
