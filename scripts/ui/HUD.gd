class_name HUD
extends CanvasLayer
## Score / best / combo / next-preview / game-over UI. Pure view layer: it
## exposes plain methods and two signals, and never reaches into gameplay.

signal restart_pressed
signal menu_pressed

@onready var score_label: Label = $Root/TopBar/ScoreLabel
@onready var best_label: Label = $Root/TopBar/BestLabel
@onready var mode_label: Label = $Root/TopBar/ModeLabel
@onready var combo_label: Label = $Root/TopBar/ComboLabel
@onready var mute_button: Button = $Root/SideBar/MuteButton
@onready var next_preview: NextFruitPreview = $Root/TopBar/NextPreviewBox/NextFruitPreview
@onready var game_over_panel: Control = $Root/GameOverPanel
@onready var final_score_label: Label = $Root/GameOverPanel/CenterContainer/Panel/VBox/FinalScoreLabel
@onready var best_final_label: Label = $Root/GameOverPanel/CenterContainer/Panel/VBox/BestFinalLabel
@onready var restart_button: Button = $Root/GameOverPanel/CenterContainer/Panel/VBox/RestartButton
@onready var menu_button: Button = $Root/GameOverPanel/CenterContainer/Panel/VBox/MenuButton

var _combo_tween: Tween


func _ready() -> void:
	game_over_panel.visible = false
	restart_button.pressed.connect(func(): restart_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())
	mute_button.pressed.connect(_on_mute_pressed)
	_refresh_mute_text()


func on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func on_best_score_changed(new_best: int) -> void:
	best_label.text = "Best: %d" % new_best


func on_mode_changed(mode: int, date: String) -> void:
	mode_label.text = ("DAILY  %s" % date) if mode == GameManager.Mode.DAILY else "FREE PLAY"


func on_next_fruit_changed(tier_id: int) -> void:
	next_preview.set_tier(tier_id)


func on_combo_changed(combo: int, multiplier: float) -> void:
	combo_label.visible = combo >= 2
	if combo < 2:
		return
	combo_label.text = "COMBO x%d  %.1fx" % [combo, multiplier]
	if _combo_tween != null and _combo_tween.is_valid():
		_combo_tween.kill()
	combo_label.scale = Vector2(1.45, 1.45)
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func show_game_over(final_score: int, best: int, mode: int, date: String) -> void:
	final_score_label.text = "Score: %d" % final_score
	best_final_label.text = ("Best today: %d" if mode == GameManager.Mode.DAILY else "Best: %d") % best
	game_over_panel.visible = true


func _on_mute_pressed() -> void:
	Sfx.toggle_mute()
	_refresh_mute_text()


func _refresh_mute_text() -> void:
	mute_button.text = "MUTED" if Sfx.muted else "SOUND"
