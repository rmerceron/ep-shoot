extends CharacterBody3D
## Player — joueur VR solo avec locomotion au joystick.
##
## Hiérarchie attendue :
##   Player (CharacterBody3D, ce script)
##   ├── XROrigin3D
##   │   ├── XRCamera3D (la tête)
##   │   ├── LeftController (XRController3D, "left_hand")   -> stick = déplacement
##   │   └── RightController (XRController3D, "right_hand") -> stick = snap-turn
##   │       └── WeaponMount/Weapon (instance de Weapon.tscn)
##   └── BodyCollision (CollisionShape3D, capsule)
##
## Déplacement : stick gauche = avancer/strafe relatif au regard.
## Stick droit : rotation par paliers (snap-turn) DÉSACTIVÉE par défaut
## (enable_snap_turn = false). La rotation se fait physiquement avec le casque.

@export var move_speed: float = 2.5
@export var gravity: float = 9.8
@export var enable_snap_turn: bool = false  # rotation au stick droit (off par défaut)
@export var snap_turn_degrees: float = 30.0
@export var snap_turn_deadzone: float = 0.7
@export var move_deadzone: float = 0.15

@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var weapon: Node3D = $XROrigin3D/RightController/WeaponMount/Weapon
@onready var body_collision: CollisionShape3D = $BodyCollision

var _can_snap := true


func _ready() -> void:
	xr_origin.current = true
	camera.current = true
	right_controller.button_pressed.connect(_on_right_button_pressed)
	right_controller.button_released.connect(_on_right_button_released)


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	if enable_snap_turn:
		_handle_snap_turn()
	_follow_head_height()


func _handle_movement(delta: float) -> void:
	var input := left_controller.get_vector2("primary")
	if input.length() < move_deadzone:
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


func _handle_snap_turn() -> void:
	var x := right_controller.get_vector2("primary").x
	if absf(x) < snap_turn_deadzone:
		_can_snap = true
		return
	if not _can_snap:
		return
	_can_snap = false
	var dir := 1.0 if x > 0.0 else -1.0
	_rotate_around_head(deg_to_rad(snap_turn_degrees) * -dir)


func _rotate_around_head(angle: float) -> void:
	# Pivote le rig autour de la tête pour que le point de vue reste stable.
	var head_before := camera.global_position
	rotate_y(angle)
	var head_after := camera.global_position
	global_position += head_before - head_after


func _follow_head_height() -> void:
	# La capsule de collision suit la hauteur réelle de la tête.
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
