extends Node
## GameState — autoload global (mode SOLO).
## Suit l'état d'un parcours : nombre de cibles, éliminations, chrono, fin.

signal targets_changed(eliminated: int, total: int)
signal course_finished(time_seconds: float)

var total_targets: int = 0
var eliminated: int = 0
var elapsed: float = 0.0
var course_active: bool = false


func start_course(total: int) -> void:
	total_targets = total
	eliminated = 0
	elapsed = 0.0
	course_active = true
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
