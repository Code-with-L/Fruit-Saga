class_name ParticleBurst
extends Node2D
## One-shot radial particle spray. Custom-drawn rather than GPUParticles2D so
## the whole effect is a single canvas item and needs no texture or sub-emitter.

var base_color: Color = Color.WHITE
var count: int = 12
var speed: float = 300.0
var particle_size: float = 6.0
var gravity: float = 900.0
var life: float = 0.55

var _parts: Array = []
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for i in count:
		var a: float = _rng.randf_range(0.0, TAU)
		var s: float = speed * _rng.randf_range(0.4, 1.0)
		_parts.append({
			"p": Vector2.ZERO,
			"v": Vector2(cos(a), sin(a)) * s,
			"r": particle_size * _rng.randf_range(0.5, 1.35),
		})


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	for part in _parts:
		part.v.y += gravity * delta
		part.p += part.v * delta
		part.v *= 1.0 - minf(3.0 * delta, 1.0)
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf(1.0 - _t / life, 0.0, 1.0)
	for part in _parts:
		draw_circle(part.p, part.r * (0.35 + 0.65 * fade), Color(base_color, fade))
