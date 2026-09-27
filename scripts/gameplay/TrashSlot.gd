class_name TrashSlot
extends Area2D
## The bin in the bottom-left corner. It swallows fruit that come to rest
## inside it, up to `total_charges` per run — the escape hatch for a run that
## is about to overflow.
##
## Like DangerZone, `_process` walks a tiny occupancy dictionary (0-3 entries)
## rather than the scene tree, because a rolling fruit only counts once its
## *centre* is inside the mouth; the Area2D signal alone fires too early.

signal charges_changed(remaining: int, total: int)

@export var total_charges: int = 3
@export var size: Vector2 = Vector2(118, 96)
@export var color: Color = Color(0.32, 0.35, 0.42)
@export var ready_color: Color = Color(0.42, 0.85, 0.55)

var charges: int = 3

var _occupants: Dictionary = {}
var _inner: Rect2
var _aim_highlight: bool = false


func _ready() -> void:
	charges = total_charges
	_inner = Rect2(-size * 0.5, size)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()
	charges_changed.emit(charges, total_charges)


func _on_body_entered(body: Node) -> void:
	if body is Fruit:
		_occupants[body] = true


func _on_body_exited(body: Node) -> void:
	_occupants.erase(body)


func _process(_delta: float) -> void:
	if charges <= 0 or _occupants.is_empty():
		return
	var doomed: Array[Fruit] = []
	for body in _occupants.keys():
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		var f := body as Fruit
		if f.is_merging:
			continue
		if _inner.has_point(f.global_position - global_position):
			doomed.append(f)
	for f in doomed:
		_consume(f)


func _consume(f: Fruit) -> void:
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


## True when the aim line is over the bin and it can still swallow something.
func is_aimed_at(world_x: float) -> bool:
	return charges > 0 and absf(world_x - global_position.x) <= size.x * 0.5


func set_aim_highlight(on: bool) -> void:
	if _aim_highlight == on:
		return
	_aim_highlight = on
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := -h * 0.5
	var tint: Color = color if charges > 0 else color.darkened(0.45)
	var body := PackedVector2Array([
		Vector2(-w * 0.46, top), Vector2(w * 0.46, top),
		Vector2(w * 0.34, h * 0.5), Vector2(-w * 0.34, h * 0.5),
	])
	draw_colored_polygon(body, tint)
	draw_rect(Rect2(-w * 0.5, top - 9.0, w, 10.0), tint.lightened(0.20))
	for i in total_charges:
		var x: float = -w * 0.5 + (float(i) + 0.5) * (w / float(total_charges))
		var pip: Color = ready_color if i < charges else Color(0.18, 0.19, 0.23, 0.65)
		draw_circle(Vector2(x, top - 23.0), 6.0, pip)
	if _aim_highlight:
		draw_rect(Rect2(-w * 0.5, top - 9.0, w, 10.0), Color(ready_color, 0.9))
