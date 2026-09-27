extends Node
## Global game state: mode, seeded RNG, score, best scores, combos, persistence.
## Fully decoupled from gameplay nodes — communicates only via signals.

signal score_changed(new_score: int)
signal best_score_changed(new_best: int)
signal game_over_triggered
signal game_started
signal combo_changed(combo: int, multiplier: float)

enum Mode { FREE, DAILY }

const SAVE_PATH := "user://savegame.cfg"

## Consecutive merges inside this window keep the combo alive.
const COMBO_WINDOW := 1.15
## Multiplier gain per extra link in the chain, and its ceiling.
const COMBO_STEP := 0.5
const COMBO_MAX_MULT := 5.0

## How many merges between Cherry Bombs.
const SPECIAL_INTERVAL := 8

var mode: int = Mode.FREE
var daily_date: String = ""
var score: int = 0
var best_score: int = 0
var is_game_over: bool = false
var run_active: bool = false
var combo: int = 0

var rng := RandomNumberGenerator.new()

var _bests: Dictionary = {}
var _combo_timer: Timer
var _special_charges: int = 0


func _ready() -> void:
	daily_date = Time.get_date_string_from_system()
	rng.randomize()
	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	_combo_timer.wait_time = COMBO_WINDOW
	_combo_timer.timeout.connect(_on_combo_timeout)
	add_child(_combo_timer)
	load_scores()


# --- run lifecycle ------------------------------------------------------

## Called by the title screen when a mode is chosen. In DAILY mode the RNG is
## seeded from the date so every player gets the identical drop sequence.
func start_run(new_mode: int) -> void:
	mode = new_mode
	daily_date = Time.get_date_string_from_system()
	if mode == Mode.DAILY:
		rng.seed = absi(hash("fruit-saga-daily-" + daily_date))
	else:
		rng.randomize()
	run_active = true
	reset_game()


## Called by Main on every scene load, including restarts. A fresh scene must
## clear the board and the score, but must NOT re-seed: retrying a daily has to
## replay the same sequence.
func ensure_run() -> void:
	if run_active:
		reset_game()
	else:
		start_run(Mode.FREE)


func reset_game() -> void:
	score = 0
	is_game_over = false
	combo = 0
	_combo_timer.stop()
	score_changed.emit(score)
	best_score_changed.emit(best_score)
	combo_changed.emit(0, 1.0)
	game_started.emit()


# --- scoring ------------------------------------------------------------

## Adds `base_points` scaled by the live combo and returns the points actually
## awarded, so callers can pop up the real number.
func add_score(base_points: int) -> int:
	if is_game_over:
		return 0
	var gained: int = int(round(float(base_points) * combo_multiplier()))
	score += gained
	score_changed.emit(score)
	if score > best_score:
		best_score = score
		_bests[_best_key(mode)] = best_score
		save_scores()
		best_score_changed.emit(best_score)
	return gained


# --- combos -------------------------------------------------------------

func notify_merge() -> int:
	combo += 1
	_combo_timer.start(COMBO_WINDOW)
	combo_changed.emit(combo, combo_multiplier())
	return combo


func combo_multiplier() -> float:
	if combo < 2:
		return 1.0
	return minf(COMBO_MAX_MULT, 1.0 + COMBO_STEP * float(combo - 1))


func _on_combo_timeout() -> void:
	if combo == 0:
		return
	combo = 0
	combo_changed.emit(0, 1.0)


# --- specials -----------------------------------------------------------

## Consumes one step of the Cherry Bomb meter; true when a bomb is due.
func consume_special_chance() -> bool:
	_special_charges += 1
	if _special_charges >= SPECIAL_INTERVAL:
		_special_charges = 0
		return true
	return false


func reset_specials() -> void:
	_special_charges = 0


# --- persistence --------------------------------------------------------

func _best_key(for_mode: int) -> String:
	if for_mode == Mode.DAILY:
		return "daily_" + daily_date
	return "free"


func get_best(for_mode: int = -1) -> int:
	var m: int = mode if for_mode < 0 else for_mode
	if m == Mode.DAILY and for_mode < 0 and daily_date == "":
		return 0
	return int(_bests.get(_best_key(m), 0))


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	save_scores()
	game_over_triggered.emit()


func save_scores() -> void:
	var cfg := ConfigFile.new()
	for key in _bests.keys():
		cfg.set_value("scores", key, _bests[key])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("Failed to save scores: %s" % err)


func load_scores() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for key in cfg.get_section_keys("scores"):
		_bests[key] = int(cfg.get_value("scores", key, 0))
	best_score = get_best(Mode.FREE)
