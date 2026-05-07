extends CharacterBody3D
## Player — joueur VR avec XROrigin3D.
##
## Hiérarchie attendue :
##   Player (CharacterBody3D, ce script)
##   ├── XROrigin3D
##   │   ├── XRCamera3D (la tête)
##   │   ├── LeftController (XRController3D, tracker = "left_hand")
##   │   │   └── (mesh main / arme secondaire)
##   │   └── RightController (XRController3D, tracker = "right_hand")
##   │       └── WeaponMount (Node3D)
##   │           └── Weapon (instance de Weapon.tscn)
##   ├── BodyCollision (CollisionShape3D, capsule grossière)
##   └── MultiplayerSynchronizer

const MAX_HEALTH := 100

@export var peer_id: int = 1

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var weapon: Node3D = $XROrigin3D/RightController/WeaponMount/Weapon
@onready var body_collision: CollisionShape3D = $BodyCollision
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

var health: int = MAX_HEALTH


func _ready() -> void:
	# Le MultiplayerSynchronizer doit être configuré pour que SEUL le joueur
	# local pousse sa transform. set_multiplayer_authority assigne ce node
	# (et tout son sous-arbre, sauf override) au peer correspondant.
	set_multiplayer_authority(peer_id)

	# Le XROrigin3D / casque ne sert qu'au joueur local. Pour le joueur distant
	# on cache la caméra (sinon elle casserait la nôtre) et on garde juste la
	# transform du casque + des contrôleurs pour montrer un avatar.
	var is_local := peer_id == multiplayer.get_unique_id()
	if not is_local:
		# Désactive le tracking XR pour ce node (joueur distant)
		camera.current = false
		# Le XROrigin3D ne doit PAS être current pour le joueur distant
		xr_origin.current = false
	else:
		xr_origin.current = true
		camera.current = true
		# Applique l'offset de calibration (voir GameState)
		xr_origin.transform = GameState.calibration_offset

	# Branche les inputs uniquement pour le joueur local
	if is_local:
		right_controller.button_pressed.connect(_on_right_button_pressed)
		right_controller.button_released.connect(_on_right_button_released)


func _physics_process(_delta: float) -> void:
	if peer_id != multiplayer.get_unique_id():
		return
	# Met à jour la position du CharacterBody3D pour qu'elle suive
	# horizontalement la position de la tête (utile pour le hitbox du joueur
	# distant et pour les collisions futures).
	var head_pos := xr_origin.transform * camera.transform.origin
	global_position.x = head_pos.x
	global_position.z = head_pos.z
	# La hauteur de la capsule suit la tête
	var head_height: float = clampf(camera.transform.origin.y, 0.5, 2.2)
	if body_collision and body_collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = body_collision.shape
		capsule.height = head_height
		body_collision.position.y = head_height * 0.5


func _on_right_button_pressed(button_name: String) -> void:
	if button_name == "trigger_click" or button_name == "trigger":
		if weapon and weapon.has_method("start_fire"):
			weapon.start_fire()


func _on_right_button_released(button_name: String) -> void:
	if button_name == "trigger_click" or button_name == "trigger":
		if weapon and weapon.has_method("stop_fire"):
			weapon.stop_fire()


# Appelé par le serveur (autorité du tireur n'est PAS l'autorité de la cible :
# le tireur émet une RPC vers le peer cible pour décrémenter sa vie côté
# autorité-cible, puis broadcast l'état via MultiplayerSynchronizer).
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: int, attacker_id: int) -> void:
	# Seul le joueur cible (autorité de ce node) applique le dégât canonique.
	if multiplayer.get_remote_sender_id() == 0:
		# Appel local : ignore (le vrai appel vient du tireur)
		pass
	if not is_multiplayer_authority():
		return
	health = max(0, health - amount)
	print("[PLAYER %d] HP=%d (touché par %d)" % [peer_id, health, attacker_id])
	if health <= 0:
		_die(attacker_id)


func _die(killer_id: int) -> void:
	if not is_multiplayer_authority():
		return
	GameState.add_score.rpc(killer_id)
	# Respawn simple après 2s
	await get_tree().create_timer(2.0).timeout
	health = MAX_HEALTH
	# Téléporte au spawn (le serveur décide)
	if multiplayer.is_server():
		_respawn_at_spawn.rpc(peer_id)


@rpc("authority", "call_local", "reliable")
func _respawn_at_spawn(_target_peer: int) -> void:
	# La logique de spawn est gérée par l'arène. Ici on remet juste à 0.
	# Pour un vrai respawn, l'arène écoute ce signal.
	pass
