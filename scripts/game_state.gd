extends Node
## GameState — autoload global.
## Stocke les infos partagées entre scènes (joueur local, scores, état du match).

signal score_changed(host_score: int, client_score: int)
signal match_ended(winner_peer_id: int)

const SCORE_TO_WIN := 5

var host_score := 0
var client_score := 0
var match_active := false

# Transformée de calibration (offset entre l'origine virtuelle et le repère
# physique partagé). Appliquée à l'XROrigin3D du joueur local après
# calibration. Voir scripts/calibration.gd.
var calibration_offset := Transform3D.IDENTITY


func reset_scores() -> void:
	host_score = 0
	client_score = 0
	match_active = true
	score_changed.emit(host_score, client_score)


@rpc("any_peer", "call_local", "reliable")
func add_score(peer_id: int) -> void:
	if not match_active:
		return
	if peer_id == 1:
		host_score += 1
	else:
		client_score += 1
	score_changed.emit(host_score, client_score)
	if host_score >= SCORE_TO_WIN:
		_end_match(1)
	elif client_score >= SCORE_TO_WIN:
		_end_match(peer_id)


func _end_match(winner: int) -> void:
	match_active = false
	match_ended.emit(winner)
