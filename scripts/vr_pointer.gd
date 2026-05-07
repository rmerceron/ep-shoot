extends Node3D
## VRPointer — laser pointer pour XRController3D.
##
## À placer comme enfant d'un XRController3D. Fait un raycast forward (-Z),
## affiche un laser et un dot d'impact, et émet `pointer_clicked(area)`
## quand la gâchette est pressée sur une Area3D `input_ray_pickable`.
##
## Hiérarchie (cf. VRPointer.tscn) :
##   VRPointer (Node3D)
##   ├── RayCast3D
##   ├── Laser (MeshInstance3D)  — BoxMesh fin (0.004, 0.004, 1)
##   └── Dot (MeshInstance3D)    — petite sphère, monde-space

signal pointer_clicked(area: Area3D)
signal pointer_entered(area: Area3D)
signal pointer_exited(area: Area3D)

@export var max_distance: float = 10.0
@export var idle_color: Color = Color(0.3, 0.6, 1.0, 0.7)
@export var hover_color: Color = Color(0.4, 1.0, 0.4, 1.0)

@onready var ray: RayCast3D = $RayCast3D
@onready var laser: MeshInstance3D = $Laser
@onready var dot: MeshInstance3D = $Dot

var _controller: XRController3D
var _current_area: Area3D = null
var _laser_mat: StandardMaterial3D
var _dot_mat: StandardMaterial3D


func _ready() -> void:
	# Cherche le XRController3D parent
	var n: Node = get_parent()
	while n:
		if n is XRController3D:
			_controller = n
			break
		n = n.get_parent()
	if _controller:
		_controller.button_pressed.connect(_on_button_pressed)
	else:
		push_warning("[VRPointer] aucun XRController3D parent trouvé")

	# Configure le ray
	ray.target_position = Vector3(0, 0, -max_distance)
	ray.collide_with_areas = true
	ray.collide_with_bodies = false

	# Crée des matériaux uniques pour ce pointeur (pour pouvoir changer
	# la couleur sans affecter d'autres pointeurs qui partageraient la
	# même ressource).
	_laser_mat = laser.get_active_material(0).duplicate() if laser.get_active_material(0) else StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.albedo_color = idle_color
	_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser.material_override = _laser_mat

	_dot_mat = dot.get_active_material(0).duplicate() if dot.get_active_material(0) else StandardMaterial3D.new()
	_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_mat.albedo_color = idle_color
	dot.material_override = _dot_mat
	dot.top_level = true  # son transform est en world-space


func _process(_delta: float) -> void:
	var hit_dist: float = max_distance
	var new_area: Area3D = null
	if ray.is_colliding():
		var col := ray.get_collider()
		if col is Area3D:
			new_area = col
		var hit_pos: Vector3 = ray.get_collision_point()
		hit_dist = ray.global_position.distance_to(hit_pos)
		dot.visible = true
		dot.global_position = hit_pos
	else:
		dot.visible = false

	# Hover events
	if new_area != _current_area:
		if _current_area:
			pointer_exited.emit(_current_area)
		if new_area:
			pointer_entered.emit(new_area)
		_current_area = new_area
		_update_color()

	# Met à jour la longueur du laser : le BoxMesh du Laser fait 1m de long
	# centré sur l'origine, on le scale en Z et on décale pour qu'il parte
	# bien de l'origine du contrôleur.
	laser.scale.z = hit_dist
	laser.position.z = -hit_dist * 0.5


func _update_color() -> void:
	var c := hover_color if _current_area else idle_color
	_laser_mat.albedo_color = c
	_dot_mat.albedo_color = c


func _on_button_pressed(button_name: String) -> void:
	if button_name != "trigger_click" and button_name != "trigger":
		return
	if _current_area:
		pointer_clicked.emit(_current_area)
