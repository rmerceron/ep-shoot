extends Node3D
## Weapon — arme VR : raycast depuis le canon, applique les dégâts à la cible.
## Mode solo : appel direct de take_damage() sur la cible touchée.
##
## Hiérarchie attendue :
##   Weapon (Node3D, ce script)
##   ├── Mesh (placeholder)
##   ├── Muzzle (Node3D — origine du tir)
##   ├── Tracer (MeshInstance3D — visuel de balle)
##   └── FireRateTimer (Timer)

signal fired(from: Vector3, to: Vector3)

@export var damage: int = 25
@export var max_range: float = 50.0
@export var fire_rate_seconds: float = 0.15
@export var auto_fire: bool = true

@onready var muzzle: Node3D = $Muzzle
@onready var tracer: MeshInstance3D = $Tracer
@onready var fire_timer: Timer = $FireRateTimer

var _firing := false
var _can_fire := true


func _ready() -> void:
	fire_timer.wait_time = fire_rate_seconds
	fire_timer.one_shot = true
	fire_timer.timeout.connect(func(): _can_fire = true)
	if tracer:
		tracer.visible = false


func start_fire() -> void:
	_firing = true
	_try_fire()


func stop_fire() -> void:
	_firing = false


func _process(_delta: float) -> void:
	if _firing and auto_fire:
		_try_fire()


func _try_fire() -> void:
	if not _can_fire:
		return
	_can_fire = false
	fire_timer.start()
	_perform_shot()


func _perform_shot() -> void:
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
	var hit_point: Vector3 = to
	if result:
		hit_point = result.position
		var hit_node = result.collider
		if hit_node and hit_node.has_method("take_damage"):
			hit_node.take_damage(damage)

	fired.emit(origin, hit_point)
	_show_tracer(origin, hit_point)


func _show_tracer(from: Vector3, to: Vector3) -> void:
	if tracer == null:
		return
	tracer.visible = true
	tracer.global_position = (from + to) * 0.5
	tracer.look_at(to, Vector3.UP)
	var dist := from.distance_to(to)
	if tracer.mesh is CylinderMesh:
		var c: CylinderMesh = tracer.mesh
		c.height = dist
	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(tracer):
			tracer.visible = false
	)


func _find_owner_player() -> CollisionObject3D:
	var n: Node = self
	while n:
		if n is CharacterBody3D:
			return n
		n = n.get_parent()
	return null
