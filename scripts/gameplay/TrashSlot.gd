class_name TrashSlot
extends Area2D
## Fixed hazard zone in the bottom-left corner. Any fruit that comes to rest in
## it is destroyed, up to `total_charges` times per run. This is deliberately a
## hazard, not a bank: nothing is stored, and there is no confirmation step —
## the fruit is simply gone.
##
## `_process` walks a small occupancy dictionary rather than the scene tree, for
## the same reason DangerZone does: the Area2D signal alone fires while a fruit
## is merely clipping the edge, whereas the zone is defined by the fruit's
## *centre* being inside `_inner`.

signal charges_changed(remaining: int, total: int)

@export var total_charges: int = 3
@export var size: Vector2 = Vector2(118, 96)
@export var color: Color = Color(0.32, 0.35, 0.42)
@export var ready_color: Color = Color(0.42, 0.85, 0.55)

## Minimum downward speed (px/s) for a fruit to count as falling *into* the
## zone rather than rolling across it.
const FALLING_MIN_VY := 26.0
## How long (msec) a fruit may sit inside the zone while moving slower than the
## above before it is consumed anyway. Without this, a fruit that rolls in
## slowly parks inside the footprint forever and blocks the column.
const SETTLE_GRACE_MSEC := 250
## Seconds for the zone to fade out once the last charge is spent.
const FADE_TIME := 0.25

var charges: int = 3

## Fruit -> msec at which it was first observed inside `_inner` while moving
## slower than FALLING_MIN_VY. 0 means "not currently inside, or still moving
## fast", so the grace timer is not running.
var _occupants: Dictionary = {}
var _inner: Rect2
var _aim_highlight: bool = false
var _fade: float = 1.0


func _ready() -> void:
	charges = total_charges
	_fade = 1.0
	_inner = Rect2(-size * 0.5, size)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()
	charges_changed.emit(charges, total_charges)


func _on_body_entered(body: Node) -> void:
	if body is Fruit:
		_occupants[body] = 0


func _on_body_exited(body: Node) -> void:
	_occupants.erase(body)


func _process(delta: float) -> void:
	_update_fade(delta)
	if charges <= 0 or _occupants.is_empty():
		return

	var now := Time.get_ticks_msec()
	var doomed: Fruit = null

	for body in _occupants.keys():
		# A fruit released to the pool is detached and then re-used elsewhere,
		# so an entry can outlive the body that created it. It has to be
		# dropped, not merely skipped: a re-used node would otherwise inherit
		# a stale grace timestamp and be consumed the instant it appears.
		if not is_instance_valid(body) or not body.is_inside_tree():
			_occupants.erase(body)
			continue
		var f := body as Fruit
		if f.is_merging:
			continue
		if not _inner.has_point(f.global_position - global_position):
			_occupants[body] = 0
			continue
		if f.linear_velocity.y >= FALLING_MIN_VY:
			# Arriving fast: consumed on the spot.
			if doomed == null:
				doomed = f
			continue
		# Inside the zone but barely moving. Start the grace timer, or let the
		# running one expire, so nothing can sit here indefinitely.
		var since := int(_occupants.get(body, 0))
		if since == 0:
			_occupants[body] = now
		elif now - since >= SETTLE_GRACE_MSEC and doomed == null:
			doomed = f

	# At most one charge per frame. A collapsing pile can still cost several
	# charges, but they land on consecutive frames so each gets its own sound,
	# burst and popup instead of stacking into a single noise.
	if doomed != null:
		_consume(doomed)


func _consume(f: Fruit) -> void:
	_occupants.erase(f)
	charges -= 1
	Sfx.play("trash", -9.0)
	GameFX.burst(f.global_position, color, 10, 240.0, 5.0)
	GameFX.popup(f.global_position, "trashed", Color(0.85, 0.55, 0.55), 22)
	GameFX.shake(2.0, 0.12)
	FruitPool.release_fruit(f)
	charges_changed.emit(charges, total_charges)
	if charges <= 0:
		_aim_highlight = false
	queue_redraw()


## The zone is a hazard, so when it runs out of charges it stops being a hazard
## rather than becoming a disabled one: it fades out entirely, so its footprint
## reads as gone instead of present-but-inert.
func _update_fade(delta: float) -> void:
	var target := 0.0 if charges <= 0 else 1.0
	if is_equal_approx(_fade, target):
		return
	_fade = move_toward(_fade, target, delta / FADE_TIME)
	queue_redraw()


## True when the aim line is over the zone and it can still destroy something.
func is_aimed_at(world_x: float) -> bool:
	return charges > 0 and absf(world_x - global_position.x) <= size.x * 0.5


func set_aim_highlight(on: bool) -> void:
	if _aim_highlight == on:
		return
	_aim_highlight = on
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.0:
		return
	var w := size.x
	var h := size.y
	var top := -h * 0.5
	var body := PackedVector2Array([
		Vector2(-w * 0.46, top), Vector2(w * 0.46, top),
		Vector2(w * 0.34, h * 0.5), Vector2(-w * 0.34, h * 0.5),
	])
	var a := _fade
	draw_colored_polygon(body, Color(color, a))
	draw_rect(Rect2(-w * 0.5, top - 9.0, w, 10.0), Color(color.lightened(0.20), a))
	for i in total_charges:
		var x: float = -w * 0.5 + (float(i) + 0.5) * (w / float(total_charges))
		var pip: Color = ready_color if i < charges else Color(0.18, 0.19, 0.23, 0.65)
		draw_circle(Vector2(x, top - 23.0), 6.0, Color(pip, pip.a * a))
	if _aim_highlight:
		draw_rect(Rect2(-w * 0.5, top - 9.0, w, 10.0), Color(ready_color, 0.9 * a))
