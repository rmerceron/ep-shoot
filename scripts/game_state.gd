extends Node
## GameState — autoload global (mode SOLO).
## Suit l'état d'un parcours : cibles, chrono, fin, et le COMBO de précision.
##
## Combo : chaque tir qui touche une cible augmente le combo (+10 % de vitesse
## de déplacement par palier, plafonné à +100 %). Un tir qui ne touche aucune
## cible (vide, mur, caisse) remet le combo à zéro. Récompense la précision.

signal targets_changed(eliminated: int, total: int)
signal course_finished(time_seconds: float)
signal combo_changed(combo: int, multiplier: float)

const SPEED_STEP := 0.1   # +10 % de vitesse par palier de combo
const COMBO_MAX := 10     # plafond : +100 % (multiplicateur max = 2.0)

var total_targets: int = 0
var eliminated: int = 0
var elapsed: float = 0.0
var course_active: bool = false
var combo: int = 0


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


func _process(delta: float) -> void:
	if course_active:
		elapsed += delta
