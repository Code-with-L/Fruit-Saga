class_name DropController
extends Node2D
## Handles touch (and mouse fallback) aiming + dropping of fruit.
## Only responds to the primary finger/mouse to keep multi-touch sane.
##
## A press that lands on a special fruit arms it instead of aiming: releasing
## on the fruit fires the ability, releasing away from it drops normally. That
## keeps one-finger play working without a second tap target.

signal fruit_dropped
signal next_fruit_changed(tier_id: int)

@export var fruit_container: Node2D
@export var left_bound: Marker2D
@export var right_bound: Marker2D
@export var drop_preview: FruitVisual
@export var trash_slot: TrashSlot
@export var drop_cooldown: float = 0.3
@export var edge_margin: float = 4.0
@export var tap_tolerance: float = 20.0

var current_tier: int = 0
var next_tier: int = 0
var can_drop: bool = true
var aim_x: float = 0.0

var _cooldown_timer: float = 0.0
var _dragging: bool = false
var _armed: Fruit = null


func _ready() -> void:
	current_tier = FruitDatabase.get_random_spawn_tier(GameManager.rng)
	next_tier = FruitDatabase.get_random_spawn_tier(GameManager.rng)
	aim_x = (left_bound.global_position.x + right_bound.global_position.x) * 0.5
	_refresh_preview_visual()
	_update_preview_position()
	next_fruit_changed.emit(next_tier)


func _process(delta: float) -> void:
	if not can_drop:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0:
			can_drop = true


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_game_over:
		return

	if event is InputEventScreenTouch:
		if event.index != 0:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventScreenDrag:
		if event.index != 0 or not _dragging:
			return
		_set_aim(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_set_aim(event.position)


func _press(screen_pos: Vector2) -> void:
	_dragging = true
	var world := _screen_to_world(screen_pos)
	var hit := MergeManager.find_fruit_at(world, tap_tolerance)
	_armed = hit if hit != null and hit.special != Fruit.Special.NONE else null
	_set_aim(screen_pos)


func _release(screen_pos: Vector2) -> void:
	_dragging = false
	if _armed != null and is_instance_valid(_armed):
		var world := _screen_to_world(screen_pos)
		if world.distance_to(_armed.global_position) <= _armed.get_radius() + tap_tolerance:
			_armed.activate_special()
			_armed = null
			can_drop = false
			_cooldown_timer = drop_cooldown
			return
	_armed = null
	_try_drop()


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	# Undo GameFX's screen shake so the aim stays under the finger while the
	# world jitters.
	return world - GameFX.world_offset()


func _set_aim(screen_pos: Vector2) -> void:
	var world_x := _screen_to_world(screen_pos).x
	var radius := FruitDatabase.get_tier(current_tier).radius
	var min_x: float = left_bound.global_position.x + edge_margin + radius
	var max_x: float = right_bound.global_position.x - edge_margin - radius
	aim_x = clampf(world_x, min_x, max_x)
	_update_preview_position()


func _update_preview_position() -> void:
	drop_preview.global_position = Vector2(aim_x, left_bound.global_position.y)
	if trash_slot != null:
		var over: bool = trash_slot.is_aimed_at(aim_x)
		trash_slot.set_aim_highlight(over)
		drop_preview.set_ghosted(over)


func _refresh_preview_visual() -> void:
	drop_preview.set_tier(current_tier)


func _try_drop() -> void:
	if not can_drop or GameManager.is_game_over:
		return
	can_drop = false
	_cooldown_timer = drop_cooldown

	var fruit := FruitPool.get_fruit(current_tier)
	var drop_pos := Vector2(aim_x, left_bound.global_position.y)
	# Add to the tree before positioning so global_position has a valid
	# transform to resolve against.
	fruit_container.add_child(fruit)
	fruit.global_position = drop_pos
	fruit.pop_in(0.85)
	Sfx.play("click", -16.0, randf_range(0.9, 1.1))
	fruit_dropped.emit()

	current_tier = next_tier
	next_tier = FruitDatabase.get_random_spawn_tier(GameManager.rng)
	_refresh_preview_visual()
	_update_preview_position()
	next_fruit_changed.emit(next_tier)
