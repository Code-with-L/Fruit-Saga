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

## Contact impulse above which a landing squashes the art, and above which it
## also plays a thud. Tuned for ~0.9-4.9 kg fruit; retune after playtesting.
const IMPACT_SQUASH := 2.0
const IMPACT_SOUND := 7.0
const IMPACT_SCALE := 400.0
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
	if is_merging:
		return
	var peak := 0.0
	for i in state.get_contact_count():
		peak = maxf(peak, state.get_contact_impulse(i).length())
	if peak < IMPACT_SQUASH:
		return
	_impact_cd = IMPACT_COOLDOWN
	_squash(Vector2(1.0 + 0.18, 1.0 - 0.18), 0.26)
	if peak >= IMPACT_SOUND:
		var loud: float = clampf(peak / 40.0, 0.0, 1.0)
		Sfx.play("drop", -20.0 + 10.0 * loud, randf_range(0.85, 1.15))


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
	if FruitDatabase.get_next_tier(tier_id) == -1:
		return  # already max tier
	MergeManager.request_merge(self, other)
