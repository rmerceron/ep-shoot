extends CharacterBody3D
## Player — joueur VR solo avec locomotion au joystick.
## Inclut un MODE BUREAU (auto-détecté si OpenXR n'est pas initialisé) :
## clavier + souris pour tester le jeu sans casque.
##
## Hiérarchie attendue :
##   Player (CharacterBody3D, ce script)
##   ├── XROrigin3D
##   │   ├── XRCamera3D
##   │   ├── LeftController (stick = déplacement)
##   │   └── RightController (WeaponMount/Weapon)
##   └── BodyCollision (CollisionShape3D, capsule)
##
## VR : stick gauche = déplacement, gâchette droite = tir.
## Stick droit (snap-turn) DÉSACTIVÉ par défaut (enable_snap_turn = false).
## Bureau : ZQSD/WASD = déplacement, souris = vue, clic gauche = tir,
##          Échap = libérer/recapturer la souris.

@export var move_speed: float = 2.5
@export var gravity: float = 9.8
@export var enable_snap_turn: bool = false  # rotation au stick droit (off par défaut)
@export var snap_turn_degrees: float = 30.0
@export var snap_turn_deadzone: float = 0.7
@export var move_deadzone: float = 0.15
@export var mouse_sensitivity: float = 0.003
@export var desktop_eye_height: float = 1.6

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var weapon: Node3D = $XROrigin3D/RightController/WeaponMount/Weapon
@onready var body_collision: CollisionShape3D = $BodyCollision

var input_enabled := true  # géré par la course (décompte de départ)
var _desktop := false
var _pitch := 0.0


func _ready() -> void:
	xr_origin.current = true
	camera.current = true
	right_controller.button_pressed.connect(_on_right_button_pressed)
	right_controller.button_released.connect(_on_right_button_released)

	# Mode bureau si OpenXR n'est pas initialisé (test sans casque).
	_desktop = not get_viewport().use_xr
	if _desktop:
		camera.position.y = desktop_eye_height
		# Sans tracking, on remonte l'arme à hauteur des yeux pour aligner
		# le laser de visée sur la vue.
		right_controller.position.y = desktop_eye_height
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	if enable_snap_turn:
		_handle_snap_turn()
	_follow_head_height()


func _handle_movement(delta: float) -> void:
	var input := _read_move_input()
	if not input_enabled or input.length() < move_deadzone:
		input = Vector2.ZERO

	# Direction relative à l'orientation de la tête (yaw uniquement).
	var cam_basis := camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var dir := (right * input.x + forward * input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()

	# Vitesse de base modulée par le combo de précision (GameState).
	var spd := move_speed * GameState.get_speed_multiplier()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()


func _read_move_input() -> Vector2:
	if _desktop:
		# Touches physiques : couvre WASD (QWERTY) et ZQSD (AZERTY, mêmes positions).
		var x := 0.0
		var y := 0.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			y -= 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			x += 1.0
		return Vector2(x, y)
	return left_controller.get_vector2("primary")


func _input(event: InputEvent) -> void:
	if not _desktop:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		camera.rotation.x = _pitch
		right_controller.rotation.x = _pitch  # l'arme vise avec la vue
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not input_enabled:
			return
		if event.pressed:
			if weapon and weapon.has_method("start_fire"):
				weapon.start_fire()
		else:
			if weapon and weapon.has_method("stop_fire"):
				weapon.stop_fire()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func _handle_snap_turn() -> void:
	var x := right_controller.get_vector2("primary").x
	if absf(x) < snap_turn_deadzone:
		return
	var dir := 1.0 if x > 0.0 else -1.0
	_rotate_around_head(deg_to_rad(snap_turn_degrees) * -dir)


func _rotate_around_head(angle: float) -> void:
	var head_before := camera.global_position
	rotate_y(angle)
	var head_after := camera.global_position
	global_position += head_before - head_after


func _follow_head_height() -> void:
	var head_height: float = clampf(camera.transform.origin.y, 0.5, 2.2)
	if body_collision and body_collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = body_collision.shape
		capsule.height = head_height
		body_collision.position.y = head_height * 0.5


func _on_right_button_pressed(button_name: String) -> void:
	if not input_enabled:
		return
	if button_name == "trigger_click" or button_name == "trigger":
		if weapon and weapon.has_method("start_fire"):
			weapon.start_fire()


func _on_right_button_released(button_name: String) -> void:
	if button_name == "trigger_click" or button_name == "trigger":
		if weapon and weapon.has_method("stop_fire"):
			weapon.stop_fire()
