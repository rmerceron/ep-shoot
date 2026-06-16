extends Node3D
## Course — mode parcours solo. Le joueur traverse un couloir au joystick et
## élimine toutes les cibles. Chrono lancé au départ, arrêté quand tout est
## éliminé. Les ennemis sont organisés en vagues réveillées par des zones de
## déclenchement (Area3D du groupe "wave_trigger").
##
## Boutons RESTART / EXIT : cachés tant que le parcours n'est pas terminé
## (pour éviter de tirer dessus par erreur), révélés à la fin.
## Raccourcis manette dispo à tout moment :
##   A / X (ax_button) = recommencer   |   B / Y (by_button) = quitter au menu

@export var player_scene: PackedScene
@export var spawn_path: NodePath
@export var menu_scene_path: String = "res://scenes/Menu.tscn"

@onready var spawn: Node3D = get_node_or_null(spawn_path)
@onready var enemies_root: Node = $Enemies
@onready var end_label: Label3D = $EndLabel
@onready var btn_restart = get_node_or_null("BtnRestart")
@onready var btn_exit = get_node_or_null("BtnExit")

var _time_label: Label3D
var _targets_label: Label3D
var _combo_label: Label3D
var _player: Node3D


func _ready() -> void:
	# Spawn du joueur local.
	if player_scene:
		_player = player_scene.instantiate()
		add_child(_player)
		if spawn:
			_player.global_position = spawn.global_position
		_attach_hud(_player)
		_connect_controller_shortcuts(_player)

	# Recense les ennemis et connecte leur élimination.
	var enemies := get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if e.has_signal("eliminated"):
			e.eliminated.connect(_on_enemy_eliminated)

	# Connecte les déclencheurs de vague.
	for trig in get_tree().get_nodes_in_group("wave_trigger"):
		if trig is Area3D:
			trig.body_entered.connect(_on_wave_trigger.bind(trig))

	# Boutons d'action (tirables) — connectés mais cachés jusqu'à la fin.
	if btn_restart and btn_restart.has_signal("knocked_down"):
		btn_restart.knocked_down.connect(_restart)
	if btn_exit and btn_exit.has_signal("knocked_down"):
		btn_exit.knocked_down.connect(_exit_to_menu)

	GameState.targets_changed.connect(_on_targets_changed)
	GameState.course_finished.connect(_on_course_finished)
	GameState.combo_changed.connect(_on_combo_changed)
	if end_label:
		end_label.visible = false

	GameState.start_course(enemies.size())


func _process(_delta: float) -> void:
	if _time_label:
		_time_label.text = "Temps : %.1f s" % GameState.elapsed


func _attach_hud(player: Node) -> void:
	# HUD ancré devant la caméra (head-locked) pour rester lisible en mouvement.
	var cam := player.get_node_or_null("XROrigin3D/XRCamera3D")
	if cam == null:
		return
	var hud := Node3D.new()
	cam.add_child(hud)
	hud.position = Vector3(0, -0.28, -1.1)

	_targets_label = Label3D.new()
	_targets_label.pixel_size = 0.0015
	_targets_label.font_size = 48
	_targets_label.modulate = Color(1, 0.85, 0.3)
	_targets_label.position = Vector3(-0.18, 0, 0)
	hud.add_child(_targets_label)

	_time_label = Label3D.new()
	_time_label.pixel_size = 0.0015
	_time_label.font_size = 48
	_time_label.position = Vector3(0.18, 0, 0)
	hud.add_child(_time_label)

	_combo_label = Label3D.new()
	_combo_label.pixel_size = 0.0018
	_combo_label.font_size = 56
	_combo_label.position = Vector3(0, 0.085, 0)
	_combo_label.modulate = Color(0.5, 0.8, 1.0)
	hud.add_child(_combo_label)
	_update_combo_label(GameState.combo, GameState.get_speed_multiplier())

	# Indice raccourcis manette.
	var hint := Label3D.new()
	hint.pixel_size = 0.0012
	hint.font_size = 40
	hint.modulate = Color(0.7, 0.75, 0.8)
	hint.position = Vector3(0, -0.06, 0)
	hint.text = "A/X : recommencer    B/Y : quitter"
	hud.add_child(hint)


func _connect_controller_shortcuts(player: Node) -> void:
	for path in ["XROrigin3D/LeftController", "XROrigin3D/RightController"]:
		var c := player.get_node_or_null(path)
		if c:
			c.button_pressed.connect(_on_controller_button)


func _on_controller_button(button_name: String) -> void:
	match button_name:
		"ax_button":
			_restart()
		"by_button":
			_exit_to_menu()


func _on_combo_changed(combo: int, multiplier: float) -> void:
	_update_combo_label(combo, multiplier)


func _update_combo_label(combo: int, multiplier: float) -> void:
	if _combo_label == null:
		return
	if combo <= 0:
		_combo_label.text = ""
		return
	var bonus := int(round((multiplier - 1.0) * 100.0))
	_combo_label.text = "COMBO x%d  (+%d%% vitesse)" % [combo, bonus]
	var t := clampf(float(combo) / float(GameState.COMBO_MAX), 0.0, 1.0)
	_combo_label.modulate = Color(0.5, 0.8, 1.0).lerp(Color(1.0, 0.55, 0.1), t)


func _on_wave_trigger(body: Node, trig: Area3D) -> void:
	if not (body is CharacterBody3D):
		return
	# Active tous les ennemis descendants du parent du déclencheur, une fois.
	var wave := trig.get_parent()
	for e in _collect_enemies(wave):
		if e.has_method("activate"):
			e.activate()
	# Désactive le déclencheur pour ne réveiller qu'une fois.
	trig.set_deferred("monitoring", false)


func _collect_enemies(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child.is_in_group("enemy"):
			out.append(child)
		out.append_array(_collect_enemies(child))
	return out


func _on_enemy_eliminated() -> void:
	GameState.register_kill()


func _on_targets_changed(eliminated: int, total: int) -> void:
	if _targets_label:
		_targets_label.text = "Cibles : %d / %d" % [eliminated, total]


func _on_course_finished(time_seconds: float) -> void:
	# Révèle les boutons tirables maintenant que le parcours est fini.
	if btn_restart and btn_restart.has_method("activate"):
		btn_restart.activate()
	if btn_exit and btn_exit.has_method("activate"):
		btn_exit.activate()
	if end_label:
		end_label.visible = true
		end_label.text = "PARCOURS TERMINE\nTemps : %.1f s\n\nTire sur RESTART / EXIT\n(ou A/X = recommencer, B/Y = quitter)" % time_seconds


func _restart() -> void:
	get_tree().reload_current_scene()


func _exit_to_menu() -> void:
	get_tree().change_scene_to_file(menu_scene_path)
