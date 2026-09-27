extends Control
## Front end: picks a mode, shows the baked fruit, reports the two bests.
## Choosing a mode calls GameManager.start_run() (which seeds the daily RNG)
## and only then swaps to the game scene, so Main never has to guess.

@onready var free_button: Button = $Root/Center/VBox/FreeButton
@onready var daily_button: Button = $Root/Center/VBox/DailyButton
@onready var free_best_label: Label = $Root/Center/VBox/FreeBestLabel
@onready var daily_date_label: Label = $Root/Center/VBox/DailyDateLabel
@onready var daily_best_label: Label = $Root/Center/VBox/DailyBestLabel
@onready var mute_button: Button = $Root/BottomBar/MuteButton

const MAIN_SCENE := "res://scenes/Main.tscn"
const SHOWCASE_TIERS := [0, 2, 4, 6, 9]

var _t: float = 0.0
var _logged_first_draw: bool = false


func _ready() -> void:
	free_button.pressed.connect(_on_free_pressed)
	daily_button.pressed.connect(_on_daily_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	_refresh_mute_text()
	_refresh_bests()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_free_pressed() -> void:
	Sfx.play("click", -8.0)
	GameManager.start_run(GameManager.Mode.FREE)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_daily_pressed() -> void:
	Sfx.play("click", -8.0)
	GameManager.start_run(GameManager.Mode.DAILY)
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_mute_pressed() -> void:
	Sfx.toggle_mute()
	_refresh_mute_text()


func _refresh_mute_text() -> void:
	mute_button.text = "MUTED" if Sfx.muted else "SOUND"


func _refresh_bests() -> void:
	var today := Time.get_date_string_from_system()
	free_best_label.text = "Best: %d" % GameManager.get_best(GameManager.Mode.FREE)
	daily_date_label.text = "Challenge for %s" % today
	daily_best_label.text = "Best today: %d" % GameManager.get_best(GameManager.Mode.DAILY)


func _draw() -> void:
	# TIMING (measurement only): ms from engine start to the first real frame of
	# the title screen, which is what the player actually waits through.
	if not _logged_first_draw:
		_logged_first_draw = true
		print("TIMING title_first_draw_ms=", Time.get_ticks_msec())
	_draw_backdrop()
	_draw_showcase()


func _draw_backdrop() -> void:
	var bands := 28
	var top := Color(0.99, 0.95, 0.97)
	var bottom := Color(0.93, 0.86, 0.95)
	for i in bands:
		var t: float = float(i) / float(bands - 1)
		var y: float = size.y * float(i) / float(bands)
		draw_rect(Rect2(0, y - 1.0, size.x, size.y / float(bands) + 2.0), top.lerp(bottom, t))


func _draw_showcase() -> void:
	for i in SHOWCASE_TIERS.size():
		var tier_id: int = SHOWCASE_TIERS[i]
		var tex := FruitArt.get_texture(tier_id)
		var half := FruitArt.get_half_size(tier_id)
		if tex == null or half <= 0.0:
			continue
		var phase: float = _t * 1.6 + float(i) * 1.1
		var bob: float = sin(phase) * 12.0
		var x: float = size.x * (0.16 + 0.17 * float(i))
		var y: float = size.y * 0.30 + bob
		draw_circle(Vector2(x, y + half * 0.92), half * 0.42, Color(0.55, 0.45, 0.60, 0.10))
		draw_texture_rect(tex, Rect2(Vector2(x, y) - Vector2.ONE * half, Vector2.ONE * half * 2.0), false)
