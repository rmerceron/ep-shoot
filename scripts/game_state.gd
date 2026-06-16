extends Node
## GameState — autoload global (mode SOLO).
## Suit l'état d'un parcours (cibles, chrono, fin), le COMBO de précision, et
## le SCOREBOARD persistant (10 meilleurs chronos, sauvés dans user://).

signal targets_changed(eliminated: int, total: int)
signal course_finished(time_seconds: float)
signal combo_changed(combo: int, multiplier: float)

const SPEED_STEP := 0.1   # +10 % de vitesse par palier de combo
const COMBO_MAX := 10     # plafond : +100 % (multiplicateur max = 2.0)

const SCORE_FILE := "user://scores.json"
const MAX_SCORES := 10

var total_targets: int = 0
var eliminated: int = 0
var elapsed: float = 0.0
var course_active: bool = false
var combo: int = 0

# scores : Array de { "name": String, "time": float }, trié par temps croissant.
var scores: Array = []


func _ready() -> void:
	_load_scores()


# --- Déroulé d'un parcours ---------------------------------------------------

## Prépare l'affichage avant le décompte (chrono figé, rien d'actif).
func prepare(total: int) -> void:
	total_targets = total
	eliminated = 0
	elapsed = 0.0
	course_active = false
	reset_combo()
	targets_changed.emit(eliminated, total_targets)


func start_course(total: int) -> void:
	total_targets = total
	eliminated = 0
	elapsed = 0.0
	course_active = true
	reset_combo()
	targets_changed.emit(eliminated, total_targets)


func register_kill() -> void:
	if not course_active:
		return
	eliminated += 1
	targets_changed.emit(eliminated, total_targets)
	if eliminated >= total_targets and total_targets > 0:
		_finish()


func _finish() -> void:
	course_active = false
	course_finished.emit(elapsed)


func _process(delta: float) -> void:
	if course_active:
		elapsed += delta


# --- Combo de précision ------------------------------------------------------

func register_hit() -> void:
	combo = mini(combo + 1, COMBO_MAX)
	combo_changed.emit(combo, get_speed_multiplier())


func register_miss() -> void:
	if combo == 0:
		return
	combo = 0
	combo_changed.emit(combo, get_speed_multiplier())


func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo, get_speed_multiplier())


func get_speed_multiplier() -> float:
	return 1.0 + float(combo) * SPEED_STEP


# --- Scoreboard --------------------------------------------------------------

## True si `time` mérite une place dans le top 10.
func qualifies(time: float) -> bool:
	if scores.size() < MAX_SCORES:
		return true
	return time < float(scores[scores.size() - 1]["time"])


## Ajoute un score, retrie, tronque au top 10 et sauvegarde.
func add_score(player_name: String, time: float) -> void:
	scores.append({"name": player_name, "time": time})
	_sort_scores()
	if scores.size() > MAX_SCORES:
		scores.resize(MAX_SCORES)
	_save_scores()


func get_scores() -> Array:
	return scores


func _sort_scores() -> void:
	scores.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))


func _load_scores() -> void:
	scores = []
	if not FileAccess.file_exists(SCORE_FILE):
		return
	var f := FileAccess.open(SCORE_FILE, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_ARRAY:
		for e in data:
			if typeof(e) == TYPE_DICTIONARY and e.has("name") and e.has("time"):
				scores.append({"name": str(e["name"]), "time": float(e["time"])})
	_sort_scores()


func _save_scores() -> void:
	var f := FileAccess.open(SCORE_FILE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(scores))
