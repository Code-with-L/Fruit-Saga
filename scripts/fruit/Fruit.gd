class_name Fruit
extends RigidBody2D
## A single physics fruit. Reports same-tier contacts to MergeManager and can
## carry a special variant (Cherry Bomb / Golden) that the player taps to fire.
## Instances are reused via FruitPool — see setup()/reset_state().
##
## Appearance is a single baked texture (see FruitArt); `squash` is a purely
## visual non-uniform scale used for the drop pop and landing impact, so the
## collision circle stays perfectly round while the art deforms.

enum Special { NONE, BOMB, GOLDEN }

const BOMB_RADIUS := 260.0
const BOMB_SCORE_MULT := 5
const GOLDEN_SCORE_MULT := 20

## Impact detection, in px/s of downward speed at the moment of contact.
## Measured on this project (headless, 720x1280, gravity 980): a fruit dropped
## from the aim line at y=90 to the floor at y=1240 lands at 1296-1344 px/s; a
## fruit dropped 120px lands at 255-437; the floor of ~255 is one physics step
## of fall, below which no contact is even registered. The brackets are scaled
## to that measured range, so k reaches 1.0 on a full-height drop.
const IMPACT_MIN_VY := 240.0
const IMPACT_VY_SOUND := 520.0
const IMPACT_VY_FULL := 1300.0
const IMPACT_SQUASH_MIN := 0.10
const IMPACT_SQUASH_MAX := 0.30
const IMPACT_COOLDOWN := 0.14

var tier_id: int = 0
var special: int = Special.NONE
var is_merging: bool = false
var spawn_time_msec: int = 0
var squash: Vector2 = Vector2.ONE

var _collision_shape: CollisionShape2D
var _tween: Tween
var _pulse: float = 0.0
var _impact_cd: float = 0.0
var _fall_speed: float = 0.0
var _dirty: bool = true


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	linear_damp = 0.1
	angular_damp = 0.6
	var mat := PhysicsMaterial.new()
	mat.friction = 0.45
	mat.bounce = 0.08
	physics_material_override = mat
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if special != Special.NONE:
		_pulse += delta * 3.6
		_dirty = true
	# A settled, non-special fruit never changes appearance, so it stops
	# repainting entirely — this is what keeps a 60-fruit board cheap.
	if _dirty:
		_dirty = false
		queue_redraw()


func _get_collision_shape() -> CollisionShape2D:
	# Resolved lazily rather than with @onready: FruitPool.get_fruit() calls
	# setup() *before* the node is added to the tree, so @onready would still
	# be null at that point.
	if _collision_shape == null or not is_instance_valid(_collision_shape):
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	return _collision_shape


## Called every time this instance is (re)used, whether freshly
## instantiated or pulled from the pool.
func setup(new_tier_id: int, new_special: int = Special.NONE) -> void:
	tier_id = new_tier_id
	special = new_special
	is_merging = false
	spawn_time_msec = Time.get_ticks_msec()
	squash = Vector2.ONE
	_pulse = 0.0
	_fall_speed = 0.0
	_impact_cd = 0.0
	_dirty = true
	var data := FruitDatabase.get_tier(tier_id)
	if data == null:
		return
	var shape := _get_collision_shape()
	if shape != null:
		shape.shape = FruitDatabase.get_shape(tier_id)  # shared, no alloc
	mass = maxf(0.5, data.radius / 20.0)
	queue_redraw()


## Called before returning to the pool.
func reset_state() -> void:
	# A SceneTreeTween bound to a node pauses when that node leaves the tree,
	# so it has to be killed explicitly or it would hang on a pooled instance.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	is_merging = false
	special = Special.NONE
	squash = Vector2.ONE
	_pulse = 0.0
	# Must be cleared: _integrate_forces ignores a merging fruit, so its
	# accumulated fall speed would otherwise survive into the next reuse and
	# fire a full-strength squash on a drop that never happened.
	_fall_speed = 0.0
	_impact_cd = 0.0
	_dirty = true
	sleeping = false


## Drop / merge flourish. Call after the node is in the tree.
func pop_in(strength: float = 1.0) -> void:
	_squash(Vector2(1.0 + 0.40 * strength, 1.0 - 0.32 * strength), 0.34)


func get_radius() -> float:
	var data := FruitDatabase.get_tier(tier_id)
	return data.radius if data else 16.0


# --- ability ------------------------------------------------------------

## Returns true if this fruit had a special that it just used.
func activate_special() -> bool:
	if special == Special.BOMB:
		_detonate()
		return true
	if special == Special.GOLDEN:
		_collect()
		return true
	return false


func _detonate() -> void:
	var data := FruitDatabase.get_tier(tier_id)
	var gained: int = GameManager.add_score(int(round(float(data.score_value) * BOMB_SCORE_MULT)))
	GameFX.shockwave(global_position, BOMB_RADIUS, Color(1.0, 0.72, 0.28), 9.0)
	GameFX.burst(global_position, Color(1.0, 0.78, 0.34), 28, 540.0, 9.0)
	GameFX.popup(global_position, "+%d" % gained, Color(1.0, 0.86, 0.36), 42)
	GameFX.shake(12.0, 0.45)
	Sfx.play("bomb", -4.0)
	MergeManager.detonate(global_position, BOMB_RADIUS)


func _collect() -> void:
	var data := FruitDatabase.get_tier(tier_id)
	var gained: int = GameManager.add_score(int(round(float(data.score_value) * GOLDEN_SCORE_MULT)))
	GameFX.shockwave(global_position, get_radius() * 3.2, Color(1.0, 0.9, 0.5), 6.0)
	GameFX.burst(global_position, Color(1.0, 0.87, 0.38), 20, 420.0, 7.0)
	GameFX.popup(global_position, "+%d" % gained, Color(1.0, 0.9, 0.42), 36)
	GameFX.shake(4.0, 0.22)
	Sfx.play("coin", -5.0)
	is_merging = true  # locks it out of merge queries while it resolves
	MergeManager.upgrade_random(self)
	FruitPool.release_fruit(self)


# --- squash & stretch ---------------------------------------------------

func _set_squash(v: Vector2) -> void:
	squash = v
	_dirty = true


func _squash(to: Vector2, duration: float) -> void:
	if not is_inside_tree():
		_set_squash(to)
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_squash, squash, to, duration * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_squash, to, Vector2.ONE, duration * 0.68).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if _impact_cd > 0.0:
		_impact_cd = maxf(0.0, _impact_cd - state.step)
		return
	if is_merging or state.get_contact_count() == 0:
		return
	# `_integrate_forces` runs *after* the solver has resolved the contact, so
	# linear_velocity is already ~0 here — reading it gives the post-impact
	# speed, not the impact speed. _fall_speed is the peak downward speed
	# accumulated over the fall by _physics_process on the previous step,
	# which is the pre-contact velocity we actually want.
	if _fall_speed < IMPACT_MIN_VY:
		return
	var speed := _fall_speed
	_fall_speed = 0.0
	_impact_cd = IMPACT_COOLDOWN
	var k := clampf(speed / IMPACT_VY_FULL, 0.0, 1.0)
	var squeeze := IMPACT_SQUASH_MIN + (IMPACT_SQUASH_MAX - IMPACT_SQUASH_MIN) * k
	_squash(Vector2(1.0 + squeeze, 1.0 - squeeze), 0.26)
	if speed >= IMPACT_VY_SOUND:
		Sfx.play("drop", -21.0 + 11.0 * k, randf_range(0.85, 1.15))


func _physics_process(_delta: float) -> void:
	_fall_speed = maxf(_fall_speed, linear_velocity.y)


# --- drawing ------------------------------------------------------------

func _draw() -> void:
	var data := FruitDatabase.get_tier(tier_id)
	if data == null:
		return
	var tex := FruitArt.get_texture(tier_id)
	var half := FruitArt.get_half_size(tier_id)
	if tex == null or half <= 0.0:
		# Pre-bake fallback: flat disc, so the very first frames never glitch.
		draw_circle(Vector2.ZERO, data.radius, data.color)
		return
	if special != Special.NONE:
		_draw_special_halo()
	draw_set_transform(Vector2.ZERO, 0.0, squash)
	draw_texture_rect(tex, Rect2(-Vector2.ONE * half, Vector2.ONE * half * 2.0), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _special_color() -> Color:
	return Color(1.0, 0.45, 0.15) if special == Special.BOMB else Color(1.0, 0.82, 0.28)


func _draw_special_halo() -> void:
	var r := get_radius()
	var col := _special_color()
	var pulse: float = 0.5 + 0.5 * sin(_pulse)
	var a: float = 0.30 + 0.35 * pulse
	draw_circle(Vector2.ZERO, r * (1.08 + 0.08 * pulse), Color(col, a * 0.32))
	draw_arc(Vector2.ZERO, r * 1.10, 0.0, TAU, 48, Color(col, a), 3.0 + 2.0 * pulse, true)
	for i in 5:
		var ang: float = _pulse * 0.9 + TAU * float(i) / 5.0
		draw_circle(Vector2(cos(ang), sin(ang)) * r * 1.26, 3.0 + 1.6 * pulse, Color(col, a))
	if special == Special.GOLDEN:
		_draw_star(Vector2.ZERO, r * 0.42, 5, Color(1.0, 0.95, 0.7, a * 0.9))
	else:
		draw_circle(Vector2(0.0, -r * 0.98), 4.0 + 2.0 * pulse, Color(1, 1, 1, a))
		draw_line(Vector2(0.0, -r * 0.9), Vector2(r * 0.16, -r * 1.12), Color(col, a), 3.0, true)


func _draw_star(center: Vector2, radius: float, points: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a: float = -PI * 0.5 + PI * float(i) / float(points)
		var rad: float = radius if i % 2 == 0 else radius * 0.44
		pts.append(center + Vector2(cos(a), sin(a)) * rad)
	draw_colored_polygon(pts, color)


func _on_body_entered(body: Node) -> void:
	if is_merging:
		return
	if not (body is Fruit):
		return
	var other := body as Fruit
	if other.is_merging or other == self:
		return
	if other.tier_id != tier_id:
		return
	# Max-tier pairs are routed too: MergeManager pays them out instead of
	# promoting them, so the board does not fill with inert watermelons.
	MergeManager.request_merge(self, other)
