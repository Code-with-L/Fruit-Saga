extends Node
## Central, easily-tunable table of all fruit tiers.
## Also pre-builds one shared CircleShape2D per tier so fruits never
## allocate a new shape resource on drop or merge (mobile perf).

var tiers: Array[FruitTier] = []
var shapes: Array[CircleShape2D] = []

## Only the first N tiers can ever be dropped by the player.
const SPAWNABLE_MAX_TIER_INDEX := 4
## Relative weights for player-dropped tiers (index-aligned, lower = rarer).
const _SPAWN_WEIGHTS := [30, 25, 20, 15, 10]

func _ready() -> void:
	tiers = [
		_make(0, "Cherry",     18.0, 1,  Color(0.86, 0.15, 0.23)),
		_make(1, "Strawberry", 24.0, 3,  Color(0.93, 0.30, 0.40)),
		_make(2, "Grape",      30.0, 6,  Color(0.56, 0.27, 0.68)),
		_make(3, "Orange",     38.0, 10, Color(0.95, 0.55, 0.10)),
		_make(4, "Apple",      46.0, 15, Color(0.80, 0.15, 0.20)),
		_make(5, "Pear",       54.0, 21, Color(0.72, 0.83, 0.24)),
		_make(6, "Peach",      62.0, 28, Color(0.98, 0.71, 0.59)),
		_make(7, "Pineapple",  72.0, 36, Color(0.96, 0.80, 0.20)),
		_make(8, "Melon",      84.0, 45, Color(0.62, 0.85, 0.45)),
		_make(9, "Watermelon", 98.0, 55, Color(0.18, 0.55, 0.30)),
	]
	shapes.clear()
	for t in tiers:
		var shp := CircleShape2D.new()
		shp.radius = t.radius
		shapes.append(shp)

func _make(id: int, name_: String, radius: float, score: int, color: Color) -> FruitTier:
	var t := FruitTier.new()
	t.tier_id = id
	t.display_name = name_
	t.radius = radius
	t.score_value = score
	t.color = color
	return t

func get_tier(tier_id: int) -> FruitTier:
	if tier_id < 0 or tier_id >= tiers.size():
		return null
	return tiers[tier_id]

func get_shape(tier_id: int) -> CircleShape2D:
	if tier_id < 0 or tier_id >= shapes.size():
		return null
	return shapes[tier_id]

## Returns -1 if tier_id is already the max tier (no further merges).
func get_next_tier(tier_id: int) -> int:
	if tier_id + 1 >= tiers.size():
		return -1
	return tier_id + 1

## Weighted-random tier for what the player is allowed to drop. Pass a seeded
## RNG for the daily challenge; leave null to use the global stream.
func get_random_spawn_tier(rng: RandomNumberGenerator = null) -> int:
	var max_idx: int = min(SPAWNABLE_MAX_TIER_INDEX, tiers.size() - 1)
	var total := 0
	for i in range(max_idx + 1):
		total += _SPAWN_WEIGHTS[i]
	var roll := 0
	if rng != null:
		roll = rng.randi() % total
	else:
		roll = randi() % total
	var acc := 0
	for i in range(max_idx + 1):
		acc += _SPAWN_WEIGHTS[i]
		if roll < acc:
			return i
	return 0
