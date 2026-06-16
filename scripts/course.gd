extends Node3D
## Course — mode parcours solo. Le joueur traverse un couloir au joystick et
## élimine toutes les cibles. Décompte 3-2-1 au départ, chrono ensuite, et à la
## fin : saisie d'initiales (style arcade) si le temps entre dans le top 10.
##
## Ennemis : groupe "enemy" (instances de Target, oneshot=true). Vagues
## réveillées par des Area3D du groupe "wave_trigger".
## Boutons RESTART / EXIT : cachés jusqu'à la fin.
## Raccourcis manette : A/X = recommencer, B/Y = quitter (à tout moment).
## Saisie d'initiales : stick gauche (haut/bas = lettre, gauche/droite = case),
## gâchette = valider.

@export var player_scene: PackedScene
@export var spawn_path: NodePath
@export var menu_scene_path: String = "res://scenes/Menu.tscn"

@onready var spawn: Node3D = get_node_or_null(spawn_path)
@onready var enemies_root: Node = $Enemies
@onready var end_label: Label3D = $EndLabel
@onready var btn_restart = get_node_or_null("BtnRestart")
@onready var btn_exit = get_node_or_null("BtnExit")

var _hud: Node3D
var _time_label: Label3D
var _targets_label: Label3D
var _combo_label: Label3D
var _countdown_label: Label3D
var _player: Node3D
var _total: int = 0
var _finish_time: float = 0.0

var _left_controller: Node = null
var _right_controller: Node = null

# Saisie d'initiales (style arcade).
var _entry_active := false
var _entry_root: Node3D
var _entry_labels: Array = []
var _letters := [0, 0, 0]
var _slot := 0
var _nav_ready := true
var _desktop := false


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

	_total = enemies.size()
	GameState.prepare(_total)
	_desktop = not get_viewport().use_xr
	if _player:
		_player.input_enabled = false
	_run_countdown()


func _input(event: InputEvent) -> void:
	# Contrôles clavier en mode bureau (test sans casque).
	if not _desktop:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _entry_active:
		match event.keycode:
			KEY_UP:
				_letters[_slot] = (_letters[_slot] + 1) % 26
				_refresh_entry_ui()
			KEY_DOWN:
				_letters[_slot] = (_letters[_slot] + 25) % 26
				_refresh_entry_ui()
			KEY_LEFT:
				_slot = (_slot + 2) % 3
				_refresh_entry_ui()
			KEY_RIGHT:
				_slot = (_slot + 1) % 3
				_refresh_entry_ui()
			KEY_ENTER, KEY_KP_ENTER:
				_confirm_name()
		return
	match event.keycode:
		KEY_R:
			_restart()
		KEY_M:
			_exit_to_menu()


func _run_countdown() -> void:
	# Décompte 3-2-1-GO : chrono figé et joueur gelé jusqu'au GO.
	for n in [3, 2, 1]:
		if not is_inside_tree():
			return
		if _countdown_label:
			_countdown_label.text = str(n)
		await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	if _countdown_label:
		_countdown_label.text = "GO !"
	GameState.start_course(_total)
	if _player:
		_player.input_enabled = true
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree() and _countdown_label:
		_countdown_label.text = ""


func _process(_delta: float) -> void:
	if _entry_active:
		_process_name_entry()
	if _time_label:
		_time_label.text = "Temps : %.1f s" % GameState.elapsed


# --- HUD ---------------------------------------------------------------------

func _attach_hud(player: Node) -> void:
	var cam := player.get_node_or_null("XROrigin3D/XRCamera3D")
	if cam == null:
		return
	_hud = Node3D.new()
	cam.add_child(_hud)
	_hud.position = Vector3(0, -0.28, -1.1)

	_targets_label = Label3D.new()
	_targets_label.pixel_size = 0.0015
	_targets_label.font_size = 48
	_targets_label.modulate = Color(1, 0.85, 0.3)
	_targets_label.position = Vector3(-0.18, 0, 0)
	_hud.add_child(_targets_label)

	_time_label = Label3D.new()
	_time_label.pixel_size = 0.0015
	_time_label.font_size = 48
	_time_label.position = Vector3(0.18, 0, 0)
	_hud.add_child(_time_label)

	_combo_label = Label3D.new()
	_combo_label.pixel_size = 0.0018
	_combo_label.font_size = 56
	_combo_label.position = Vector3(0, 0.085, 0)
	_combo_label.modulate = Color(0.5, 0.8, 1.0)
	_hud.add_child(_combo_label)
	_update_combo_label(GameState.combo, GameState.get_speed_multiplier())

	_countdown_label = Label3D.new()
	_countdown_label.pixel_size = 0.004
	_countdown_label.font_size = 96
	_countdown_label.position = Vector3(0, 0.32, 0)
	_countdown_label.modulate = Color(1, 0.95, 0.4)
	_countdown_label.text = ""
	_hud.add_child(_countdown_label)


func _connect_controller_shortcuts(player: Node) -> void:
	_left_controller = player.get_node_or_null("XROrigin3D/LeftController")
	_right_controller = player.get_node_or_null("XROrigin3D/RightController")
	for c in [_left_controller, _right_controller]:
		if c:
			c.button_pressed.connect(_on_controller_button)


func _on_controller_button(button_name: String) -> void:
	# Pendant la saisie, la gâchette valide les initiales.
	if _entry_active and (button_name == "trigger_click" or button_name == "trigger"):
		_confirm_name()
		return
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


# --- Vagues / cibles ---------------------------------------------------------

func _on_wave_trigger(body: Node, trig: Area3D) -> void:
	if not (body is CharacterBody3D):
		return
	var wave := trig.get_parent()
	for e in _collect_enemies(wave):
		if e.has_method("activate"):
			e.activate()
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


# --- Fin de parcours + saisie d'initiales ------------------------------------

func _on_course_finished(time_seconds: float) -> void:
	_finish_time = time_seconds
	if _player:
		_player.input_enabled = false  # gèle tir/déplacement pendant l'épilogue
	if GameState.qualifies(time_seconds):
		_start_name_entry()
	else:
		_reveal_end("Pas dans le top 10")


func _reveal_end(extra_line: String) -> void:
	if _player:
		_player.input_enabled = true
	if btn_restart and btn_restart.has_method("activate"):
		btn_restart.activate()
	if btn_exit and btn_exit.has_method("activate"):
		btn_exit.activate()
	if end_label:
		end_label.visible = true
		end_label.text = "PARCOURS TERMINE\nTemps : %.1f s\n%s\n\nTire sur RESTART / EXIT\n(ou A/X = recommencer, B/Y = quitter)" % [_finish_time, extra_line]


func _start_name_entry() -> void:
	_entry_active = true
	_letters = [0, 0, 0]
	_slot = 0
	_nav_ready = true
	if _hud == null:
		# Pas de HUD : on enregistre un nom par défaut et on termine.
		GameState.add_score("AAA", _finish_time)
		_reveal_end("Enregistre : AAA")
		return
	_entry_root = Node3D.new()
	_hud.add_child(_entry_root)
	_entry_root.position = Vector3(0, 0.18, 0)

	var info := Label3D.new()
	info.pixel_size = 0.0013
	info.font_size = 40
	info.modulate = Color(1, 0.9, 0.3)
	info.position = Vector3(0, 0.07, 0)
	info.text = "NOUVEAU TOP 10 ! Entre tes initiales\nStick: lettre / case    Gachette: valider"
	_entry_root.add_child(info)

	_entry_labels = []
	for i in 3:
		var l := Label3D.new()
		l.pixel_size = 0.003
		l.font_size = 72
		l.position = Vector3((float(i) - 1.0) * 0.12, 0, 0)
		_entry_root.add_child(l)
		_entry_labels.append(l)
	_refresh_entry_ui()


func _refresh_entry_ui() -> void:
	for i in _entry_labels.size():
		var l: Label3D = _entry_labels[i]
		l.text = String.chr(65 + _letters[i])
		l.modulate = Color(1, 1, 0.4) if i == _slot else Color(0.8, 0.85, 0.9)


func _process_name_entry() -> void:
	if _left_controller == null:
		return
	var v: Vector2 = _left_controller.get_vector2("primary")
	if v.length() < 0.3:
		_nav_ready = true
		return
	if not _nav_ready:
		return
	if absf(v.y) > absf(v.x):
		if v.y > 0.6:
			_letters[_slot] = (_letters[_slot] + 1) % 26
			_nav_ready = false
		elif v.y < -0.6:
			_letters[_slot] = (_letters[_slot] + 25) % 26
			_nav_ready = false
	else:
		if v.x > 0.6:
			_slot = (_slot + 1) % 3
			_nav_ready = false
		elif v.x < -0.6:
			_slot = (_slot + 2) % 3
			_nav_ready = false
	if not _nav_ready:
		_refresh_entry_ui()


func _confirm_name() -> void:
	if not _entry_active:
		return
	_entry_active = false
	var nm := ""
	for i in 3:
		nm += String.chr(65 + _letters[i])
	GameState.add_score(nm, _finish_time)
	if is_instance_valid(_entry_root):
		_entry_root.queue_free()
	_reveal_end("Enregistre : %s" % nm)


func _restart() -> void:
	get_tree().reload_current_scene()


func _exit_to_menu() -> void:
	get_tree().change_scene_to_file(menu_scene_path)
