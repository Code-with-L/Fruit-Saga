extends Node
## Simple object pool for Fruit instances to avoid instantiate()/free()
## churn every drop, merge and bomb — important on mobile.
##
## The pool is an autoload, so it outlives scene reloads. Fruits that were
## still on the board when the scene was reloaded get freed by the scene
## tree, which leaves dangling references here — hence the validity check
## on pop in get_fruit().

const FRUIT_SCENE: PackedScene = preload("res://scenes/fruit/Fruit.tscn")

var _pool: Array[Fruit] = []

func get_fruit(tier_id: int, special: int = Fruit.Special.NONE) -> Fruit:
	var fruit: Fruit = null
	while not _pool.is_empty():
		var candidate: Fruit = _pool.pop_back()
		if is_instance_valid(candidate):
			fruit = candidate
			break
	if fruit == null:
		fruit = FRUIT_SCENE.instantiate()
	fruit.setup(tier_id, special)
	return fruit

func release_fruit(fruit: Fruit) -> void:
	if not is_instance_valid(fruit):
		return
	if fruit.get_parent():
		fruit.get_parent().remove_child(fruit)
	fruit.reset_state()
	_pool.append(fruit)
