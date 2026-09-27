class_name DangerZone
extends Area2D
## Detects a "settled" fruit overflowing the top of the container.
## Uses Area2D enter/exit signals (event-driven) to maintain a small
## occupancy dictionary; a Timer (also signal-driven) fires game over
## if the overflow persists continuously for `danger_seconds`.
##
## NOTE: `_process` here only iterates this tiny dictionary (0-3 items
## in practice), not the whole scene — this is a deliberate, cheap
## exception to "no polling", needed to measure elapsed time.

@export var settle_grace_ms: int = 1500
@export var danger_seconds: float = 3.0

@onready var timer: Timer = $Timer

var _occupants: Dictionary = {}  # Fruit -> entry time (msec)
var _danger_bottom: float = 0.0
var _prune: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	timer.wait_time = danger_seconds
	timer.one_shot = true
	timer.timeout.connect(_on_timeout)

	var shape := ($CollisionShape2D as CollisionShape2D).shape as RectangleShape2D
	if shape != null:
		_danger_bottom = global_position.y + shape.size.y * 0.5

func _on_body_entered(body: Node) -> void:
	if body is Fruit:
		_occupants[body] = Time.get_ticks_msec()

func _on_body_exited(body: Node) -> void:
	_occupants.erase(body)

func _process(_delta: float) -> void:
	if _occupants.is_empty():
		if not timer.is_stopped():
			timer.stop()
		return

	var now := Time.get_ticks_msec()
	var breach := false
	_prune.clear()
	for body in _occupants.keys():
		# Pooled fruits are detached from the tree and re-used for other
		# fruits elsewhere, so an entry can outlive the body that created it.
		# Drop those (and anything whose top edge has cleared the line).
		if not is_instance_valid(body) or not body.is_inside_tree():
			_prune.append(body)
			continue
		if (body as Fruit).global_position.y - (body as Fruit).get_radius() > _danger_bottom:
			_prune.append(body)
			continue
		if now - int(_occupants[body]) >= settle_grace_ms:
			breach = true
	for body in _prune:
		_occupants.erase(body)

	if breach and timer.is_stopped():
		timer.start()
	elif not breach and not timer.is_stopped():
		timer.stop()

func _on_timeout() -> void:
	GameManager.trigger_game_over()
