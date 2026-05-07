extends Node3D
## Arena — scène de jeu. Spawn les joueurs (host = peer 1, client = peer != 1)
## et lance la séquence de calibration.

@export var player_scene: PackedScene
@export var spawn_host_path: NodePath
@export var spawn_client_path: NodePath
@export var calibration_path: NodePath

@onready var spawn_host: Node3D = get_node_or_null(spawn_host_path)
@onready var spawn_client: Node3D = get_node_or_null(spawn_client_path)
@onready var calibration: Node = get_node_or_null(calibration_path)
@onready var hud_label: Label3D = $HUD/ScoreLabel


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.match_ended.connect(_on_match_ended)
	GameState.reset_scores()

	# Le serveur (host) spawn les deux joueurs.
	if multiplayer.is_server():
		_spawn_player(1)  # host
		# Si un client est déjà connecté quand on arrive sur l'arène
		for id in multiplayer.get_peers():
			_spawn_player(id)
		# Et écoute les futurs connectés
		multiplayer.peer_connected.connect(_spawn_player)


func _spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if player_scene == null:
		push_error("[ARENA] player_scene non assignée")
		return
	var p: Node = player_scene.instantiate()
	p.name = "Player_%d" % peer_id
	p.peer_id = peer_id
	add_child(p, true)  # true = force_readable_name pour la sync
	# Position de spawn — ATTENTION : en VR avec arène = pièce physique,
	# le spawn virtuel doit correspondre à où le joueur se trouve PHYSIQUEMENT.
	# Donc en réalité, après calibration, le joueur EST déjà au bon endroit.
	# Ces spawn points ne servent que pour les téléportations de respawn.
	var spawn: Node3D = spawn_host if peer_id == 1 else spawn_client
	if spawn:
		p.global_position = spawn.global_position


func _on_score_changed(host: int, client: int) -> void:
	if hud_label:
		hud_label.text = "%d  -  %d" % [host, client]


func _on_match_ended(winner: int) -> void:
	if hud_label:
		var who := "HOST" if winner == 1 else "CLIENT"
		hud_label.text = "%s GAGNE !" % who
