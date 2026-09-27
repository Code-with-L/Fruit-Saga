extends Node
## Resolves fruit merges outside of physics collision callbacks, and owns
## everything that removes or upgrades live fruit (bombs, golden pickups).
##
## Fruits report candidate merges via request_merge() during their
## body_entered signal (fired by the physics server mid-step). We only
## record the pair and lock both fruits here; the actual node removal /
## spawn happens in _physics_process on the *next* safe tick, which is
## the recommended pattern for mutating RigidBody2D state in response
## to collisions in Godot.

const GOLDEN_CHANCE := 0.025
const BOMB_RADIUS := 260.0
const BOMB_SCORE_MULT := 5
const GOLDEN_SCORE_MULT := 20

var fruit_container: Node2D
var _pending: Array[Array] = []


func _ready() -> void:
	# Root's inherited mode is effectively PAUSABLE, but state it explicitly
	# so the merge queue reliably freezes when the game-over pause kicks in.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(container: Node2D) -> void:
	fruit_container = container
	_pending.clear()
	GameManager.reset_specials()


func request_merge(a: Fruit, b: Fruit) -> void:
	if a.is_merging or b.is_merging:
		return
	a.is_merging = true
	b.is_merging = true
	_pending.append([a, b])


func _physics_process(_delta: float) -> void:
	if _pending.is_empty():
		return
	var batch := _pending.duplicate()
	_pending.clear()
	for pair in batch:
		_process_merge(pair[0], pair[1])


func _process_merge(a: Fruit, b: Fruit) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	if fruit_container == null or not is_instance_valid(fruit_container):
		return
	var tier_id := a.tier_id
	var next_tier := FruitDatabase.get_next_tier(tier_id)
	var mid_pos: Vector2 = (a.global_position + b.global_position) * 0.5

	var tier_data := FruitDatabase.get_tier(tier_id)
	if tier_data == null:
		return
	var combo: int = GameManager.notify_merge()
	var gained: int = GameManager.add_score(tier_data.score_value)

	GameFX.burst(mid_pos, tier_data.color, 10 + mini(combo, 8) * 2, 260.0 + mini(combo, 8) * 30.0, 6.0)
	GameFX.popup(mid_pos, "+%d" % gained, Color(1, 1, 1), 30)
	GameFX.shockwave(mid_pos, tier_data.radius * 2.2, tier_data.color, 5.0)
	GameFX.shake(2.0 + float(mini(combo, 6)) * 0.9, 0.2)
	if combo >= 2:
		GameFX.popup(mid_pos + Vector2(0, -46), "COMBO x%d" % combo, Color(1.0, 0.86, 0.35), 34)
	Sfx.play("merge", -12.0, clampf(0.9 + 0.07 * float(combo), 0.9, 1.7))

	FruitPool.release_fruit(a)
	FruitPool.release_fruit(b)

	if next_tier == -1:
		return  # max tier reached, nothing new spawns

	var new_fruit := FruitPool.get_fruit(next_tier, _roll_special())
	# Add to the tree *before* positioning: a node that is not inside the
	# tree yet has no valid global transform to offset from.
	fruit_container.add_child(new_fruit)
	new_fruit.global_position = mid_pos
	new_fruit.pop_in()


## Cherry Bombs are deterministic (every N merges) so players can plan around
## them; Golden fruit is a rare bonus roll. Both read the run RNG, so a daily
## challenge replays identically.
func _roll_special() -> int:
	if GameManager.consume_special_chance():
		return Fruit.Special.BOMB
	if GameManager.rng.randf() < GOLDEN_CHANCE:
		return Fruit.Special.GOLDEN
	return Fruit.Special.NONE


# --- live fruit queries -------------------------------------------------

## Walks the container's direct children. Cheap: the board holds tens of
## fruit, not thousands, and this only runs on a user-triggered ability.
func get_live_fruits() -> Array[Fruit]:
	var out: Array[Fruit] = []
	if fruit_container == null or not is_instance_valid(fruit_container):
		return out
	for child in fruit_container.get_children():
		if child is Fruit:
			out.append(child)
	return out


## Nearest fruit whose body is within `extra` pixels of a tap — used so a
## touch activates a special fruit instead of dropping a new one.
func find_fruit_at(world_pos: Vector2, extra: float = 16.0) -> Fruit:
	var best: Fruit = null
	var best_d: float = INF
	for f in get_live_fruits():
		if f.is_merging:
			continue
		var d: float = f.global_position.distance_to(world_pos)
		if d <= f.get_radius() + extra and d < best_d:
			best_d = d
			best = f
	return best


# --- abilities ----------------------------------------------------------

## Cherry Bomb: destroy everything inside `radius`, scoring each victim.
func detonate(center: Vector2, radius: float) -> int:
	var doomed: Array[Fruit] = []
	for f in get_live_fruits():
		if f.is_merging:
			continue
		if f.global_position.distance_to(center) <= radius:
			doomed.append(f)
	for f in doomed:
		var data := FruitDatabase.get_tier(f.tier_id)
		GameManager.add_score(data.score_value)
		GameFX.burst(f.global_position, data.color, 6, 300.0, 5.0)
		FruitPool.release_fruit(f)
	return doomed.size()


## Golden fruit payout: promote one random fruit on the board a tier.
func upgrade_random(exclude: Fruit = null) -> bool:
	var candidates: Array[Fruit] = []
	for f in get_live_fruits():
		if f == exclude or f.is_merging:
			continue
		if FruitDatabase.get_next_tier(f.tier_id) != -1:
			candidates.append(f)
	if candidates.is_empty():
		return false
	var target: Fruit = candidates[GameManager.rng.randi() % candidates.size()]
	var pos := target.global_position
	var next := FruitDatabase.get_next_tier(target.tier_id)
	var carried := target.special
	FruitPool.release_fruit(target)

	var up := FruitPool.get_fruit(next, carried)
	fruit_container.add_child(up)
	up.global_position = pos
	up.pop_in(0.7)
	GameFX.burst(pos, FruitDatabase.get_tier(next).color, 14, 280.0, 6.0)
	GameFX.popup(pos, "UP!", Color(1.0, 0.88, 0.4), 26)
	return true
