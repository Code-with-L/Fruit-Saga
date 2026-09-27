extends Node
## Screen shake and one-shot visual effects (bursts, floating text, shockwaves).
##
## Screen shake is the one place the game offsets a transform every frame; it
## drives `world.position` (the gameplay root) so walls, fruits and the danger
## zone all move together and physics is untouched. Effects themselves are
## self-freeing nodes parented to `fx_layer`.

const MAX_SHAKE := 14.0

var world: Node2D
var fx_layer: Node2D

var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _shake_power: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func setup(world_node: Node2D, layer: Node2D) -> void:
	world = world_node
	fx_layer = layer
	world.position = Vector2.ZERO
	_shake_left = 0.0


## Current shake offset, so aim input can stay aligned with the shaken world.
func world_offset() -> Vector2:
	return world.position if world else Vector2.ZERO


func shake(power: float, duration: float = 0.25) -> void:
	power = minf(power, MAX_SHAKE)
	if power <= _shake_power and duration <= _shake_left:
		return
	_shake_power = maxf(_shake_power, power)
	_shake_total = maxf(_shake_total, duration)
	_shake_left = maxf(_shake_left, duration)


func _process(delta: float) -> void:
	if _shake_left <= 0.0 or world == null:
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		_shake_left = 0.0
		_shake_power = 0.0
		_shake_total = 0.0
		world.position = Vector2.ZERO
		return
	var k: float = _shake_left / maxf(_shake_total, 0.001)
	var amp: float = _shake_power * k * k
	world.position = Vector2(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp))


func burst(pos: Vector2, color: Color, count: int = 12, speed: float = 300.0, size: float = 6.0) -> void:
	if fx_layer == null:
		return
	var b := ParticleBurst.new()
	b.position = pos
	b.base_color = color
	b.count = count
	b.speed = speed
	b.particle_size = size
	fx_layer.add_child(b)


func popup(pos: Vector2, text: String, color: Color, size: int = 30) -> void:
	if fx_layer == null:
		return
	var t := FloatingText.new()
	t.position = pos
	t.text = text
	t.color = color
	t.font_size = size
	fx_layer.add_child(t)


func shockwave(pos: Vector2, radius: float, color: Color, width: float = 7.0) -> void:
	if fx_layer == null:
		return
	var s := Shockwave.new()
	s.position = pos
	s.radius = radius
	s.color = color
	s.width = width
	fx_layer.add_child(s)
