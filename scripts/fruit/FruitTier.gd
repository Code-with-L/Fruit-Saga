class_name FruitTier
extends Resource
## Tunable data for one fruit tier. Kept tiny and data-only so designers
## can retune balance without touching gameplay code.

@export var tier_id: int = 0
@export var display_name: String = ""
@export var radius: float = 16.0
@export var score_value: int = 1
@export var color: Color = Color.WHITE
