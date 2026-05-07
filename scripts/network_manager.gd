extends Node
## NetworkManager — autoload qui gère le multijoueur ENet (LAN Wi-Fi).
##
## Modèle : peer-to-peer simple, host = serveur autoritaire (peer_id 1),
## client = peer_id 2. RPCs pour les dégâts et la sync d'état.

signal connection_succeeded
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)

const DEFAULT_PORT := 8910
const MAX_CLIENTS := 1  # 1v1

var is_host := false
var local_peer_id := 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("Impossible de créer le serveur : %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_peer_id = 1
	print("[NET] Host démarré sur le port %d" % port)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Impossible de se connecter : %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("[NET] Connexion à %s:%d ..." % [address, port])
	return OK


func leave_game() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	local_peer_id = 0


func _on_peer_connected(id: int) -> void:
	print("[NET] Peer connecté : %d" % id)
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	print("[NET] Peer déconnecté : %d" % id)
	peer_disconnected.emit(id)


func _on_connected_ok() -> void:
	local_peer_id = multiplayer.get_unique_id()
	print("[NET] Connecté au serveur, mon id = %d" % local_peer_id)
	connection_succeeded.emit()


func _on_connected_fail() -> void:
	push_warning("[NET] Connexion échouée")
	multiplayer.multiplayer_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("[NET] Serveur déconnecté")
	multiplayer.multiplayer_peer = null
