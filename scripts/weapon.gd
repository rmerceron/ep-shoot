extends Node3D
## Weapon — arme VR : laser de visée + raycast depuis le canon.
##
## Un laser part en continu du canon (Muzzle) pour montrer EXACTEMENT où on
## tire, avec un point d'impact. Le tir utilise la même origine/direction que
## le laser, donc la balle part toujours pile où pointe le laser.
##
## Hiérarchie attendue :
##   Weapon (Node3D, ce script)
##   ├── Mesh
##   ├── Muzzle (Node3D — origine du tir, -Z = avant)
##   │   └── AimLaser (MeshInstance3D — BoxMesh fin de 1 m sur Z)
##   ├── AimDot (MeshInstance3D — sphère, point d'impact, top_level)
##   └── FireRateTimer (Timer)

signal fired(from: Vector3, to: Vector3)

@export var damage: int = 25
@export var max_range: float = 50.0
@export var fire_rate_seconds: float = 0.15
@export var auto_fire: bool = true
@export var idle_color: Color = Color(0.3, 0.7, 1.0, 0.6)
@export var fire_color: Color = Color(1.0, 0.85, 0.3, 1.0)

@onready var muzzle: Node3D = $Muzzle
@onready var aim_laser: MeshInstance3D = $Muzzle/AimLaser
@onready var aim_dot: MeshInstance3D = $AimDot
@onready var fire_timer: Timer = $FireRateTimer

var _firing := false
var _can_fire := true
var _laser_mat: StandardMaterial3D
var _dot_mat: StandardMaterial3D
var _flash := 0.0


func _ready() -> void:
	fire_timer.wait_time = fire_rate_seconds
	fire_timer.one_shot = true
	fire_timer.timeout.connect(func(): _can_fire = true)

	# Matériaux uniques pour ce laser (couleur modifiable au tir).
	if aim_laser:
		_laser_mat = StandardMaterial3D.new()
		_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_laser_mat.albedo_color = idle_color
		aim_laser.material_override = _laser_mat
	if aim_dot:
		_dot_mat = StandardMaterial3D.new()
		_dot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_dot_mat.albedo_color = idle_color
		aim_dot.material_override = _dot_mat
		aim_dot.top_level = true


func start_fire() -> void:
	_firing = true
	_try_fire()


func stop_fire() -> void:
	_firing = false


func _process(delta: float) -> void:
	_update_aim()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		var c := idle_color.lerp(fire_color, _flash)
		if _laser_mat:
			_laser_mat.albedo_color = c
		if _dot_mat:
			_dot_mat.albedo_color = c
	if _firing and auto_fire:
		_try_fire()


## Lance un rayon depuis le canon et renvoie le résultat (ou null).
func _cast() -> Dictionary:
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	var origin := muzzle.global_position
	var forward := -muzzle.global_transform.basis.z.normalized()
	var to := origin + forward * max_range
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var self_player := _find_owner_player()
	if self_player:
		query.exclude = [self_player.get_rid()]
	var result := space.intersect_ray(query)
	return {"origin": origin, "to": to, "result": result}


func _update_aim() -> void:
	if aim_laser == null:
		return
	var data := _cast()
	if data.is_empty():
		return
	var origin: Vector3 = data["origin"]
	var hit_point: Vector3 = data["to"]
	if data["result"]:
		hit_point = data["result"].position
	var dist: float = origin.distance_to(hit_point)
	# Le BoxMesh fait 1 m de long centré sur l'origine : on l'étire sur Z.
	aim_laser.scale.z = dist
	aim_laser.position.z = -dist * 0.5
	if aim_dot:
		aim_dot.visible = true
		aim_dot.global_position = hit_point


func _try_fire() -> void:
	if not _can_fire:
		return
	_can_fire = false
	fire_timer.start()
	_perform_shot()


func _perform_shot() -> void:
	var data := _cast()
	if data.is_empty():
		return
	var origin: Vector3 = data["origin"]
	var hit_point: Vector3 = data["to"]
	var combo_hit := false
	if data["result"]:
		hit_point = data["result"].position
		var hit_node = data["result"].collider
		if hit_node and hit_node.has_method("take_damage"):
			hit_node.take_damage(damage)
			# Les boutons d'action (RESTART/EXIT) ne comptent pas dans le combo.
			if not hit_node.is_in_group("action_button"):
				combo_hit = true
	# Combo : toucher une cible -> +1 ; sinon (vide / mur / caisse) -> reset.
	if combo_hit:
		GameState.register_hit()
	else:
		GameState.register_miss()
	_flash = 1.0
	fired.emit(origin, hit_point)


func _find_owner_player() -> CollisionObject3D:
	var n: Node = self
	while n:
		if n is CharacterBody3D:
			return n
		n = n.get_parent()
	return null
