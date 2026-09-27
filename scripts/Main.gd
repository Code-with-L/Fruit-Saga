extends Node2D
## Scene entry point: wires autoloads to gameplay nodes, owns game flow.
## Children are already inside the tree here, so every @onready is resolved.
##
## `World` is the gameplay root; GameFX offsets it for screen shake, which
## moves walls, fruit, the bin and the aim line together without touching
## physics. `FXLayer` sits outside it so effects are never shaken, and runs
## while the tree is paused so the last popups still land.

@onready var world: Node2D = $World
@onready var fruit_container: Node2D = $World/FruitContainer
@onready var drop_controller: DropController = $World/DropController
@onready var danger_zone: DangerZone = $World/DangerZone
@onready var trash_slot: TrashSlot = $World/TrashSlot
@onready var fx_layer: Node2D = $FXLayer
@onready var hud: HUD = $HUD

const MAIN_SCENE := "res://scenes/Main.tscn"
const TITLE_SCENE := "res://scenes/ui/TitleScreen.tscn"


func _ready() -> void:
	# Clears the board's score for a fresh scene but keeps the run's mode and
	# seed, so retrying a daily replays the identical drop sequence.
	GameManager.ensure_run()
	GameFX.setup(world, fx_layer)
	MergeManager.setup(fruit_container)

	GameManager.score_changed.connect(hud.on_score_changed)
	GameManager.best_score_changed.connect(hud.on_best_score_changed)
	GameManager.game_over_triggered.connect(_on_game_over)
	drop_controller.next_fruit_changed.connect(hud.on_next_fruit_changed)
	hud.restart_pressed.connect(_on_restart_pressed)
	hud.menu_pressed.connect(_on_menu_pressed)

	hud.on_score_changed(GameManager.score)
	hud.on_best_score_changed(GameManager.best_score)
	hud.on_next_fruit_changed(drop_controller.next_tier)
	hud.on_mode_changed(GameManager.mode, GameManager.daily_date)


func _on_game_over() -> void:
	hud.show_game_over(GameManager.score, GameManager.best_score, GameManager.mode, GameManager.daily_date)
	get_tree().paused = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
