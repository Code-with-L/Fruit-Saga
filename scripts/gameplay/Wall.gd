extends StaticBody2D
## Procedural placeholder visual for container walls/floor.
## The collision shape is (re)sized from `size` in code so the exported
## size and the RectangleShape2D can never drift apart.

@export var size: Vector2 = Vector2(20, 1000)
@export var color: Color = Color(0.30, 0.32, 0.38)

func _ready() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		add_child(collision)
	var shape := collision.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision.shape = shape
	shape.size = size
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-size / 2.0, size), color)
