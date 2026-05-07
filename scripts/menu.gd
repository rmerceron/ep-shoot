extends Node3D
## Menu VR — permet de Host ou Join. UI 3D simple en world-space.
## Interaction via VRPointer (laser sur le contrôleur droit).

@export var arena_scene: PackedScene

@onready var status_label: Label3D = $StatusLabel
@onready var ip_input_label: Label3D = $IpInput/Label
@onready var btn_host: Area3D = $BtnHost
@onready var btn_join: Area3D = $BtnJoin
@onready var pointer: Node = $XROrigin3D/RightController/VRPointer

var ip_text := "127.0.0.1"


func _ready() -> void:
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	if pointer:
		pointer.pointer_clicked.connect(_on_pointer_clicked)
	# Fallback souris pour debug en éditeur sans casque
	btn_host.input_event.connect(_on_btn_input.bind("host"))
	btn_join.input_event.connect(_on_btn_input.bind("join"))
	_update_ip_display()


func _update_ip_display() -> void:
	if ip_input_label:
		ip_input_label.text = "IP host : %s" % ip_text


func _on_pointer_clicked(area: Area3D) -> void:
	if area == btn_host:
		_handle_action("host")
	elif area == btn_join:
		_handle_action("join")


func _on_btn_input(_camera, event: InputEvent, _pos, _normal, _idx, action: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		_handle_action(action)


func _handle_action(action: String) -> void:
	match action:
		"host":
			status_label.text = "Hosting... en attente de l'autre joueur"
			NetworkManager.host_game()
		"join":
			status_label.text = "Connexion à %s ..." % ip_text
			NetworkManager.join_game(ip_text)


func _on_connected() -> void:
	status_label.text = "Connecté ! Lancement..."
	_load_arena()


func _on_connection_failed() -> void:
	status_label.text = "Échec connexion. Vérifie l'IP."


func _on_peer_connected(_id: int) -> void:
	if NetworkManager.is_host:
		status_label.text = "Joueur connecté ! Lancement..."
		_load_arena()


func _load_arena() -> void:
	if arena_scene:
		get_tree().change_scene_to_packed(arena_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/Arena.tscn")
