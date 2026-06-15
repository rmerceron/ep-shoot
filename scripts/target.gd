extends AnimatableBody3D
## Target — cible/ennemi tirable.
##
## Mode parcours : `oneshot = true` (l'ennemi reste à terre une fois éliminé)
## et émet `eliminated` à la première chute.
## Peut démarrer dormant (`start_active = false`) puis être réveillé par une
## vague via activate() : il se redresse avec un petit effet de "pop-up".
## Peut osciller horizontalement (cible mobile).
##
## Émet `hit_registered(damage)` à chaque tir, `eliminated` à l'élimination,
## et `knocked_down` à chaque chute (compat. rétro).
##
## Hiérarchie : AnimatableBody3D + CollisionShape3D + Mesh (Node3D géométrie).

signal hit_registered(damage: int)
signal knocked_down
signal eliminated

@export var hp: int = 1
@export var respawn_delay: float = 2.0
@export var oneshot: bool = false
@export var start_active: bool = true
@export var oscillate: bool = false
@export var oscillate_amplitude: float = 1.5
@export var oscillate_speed: float = 1.0

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var mesh_root: Node3D = $Mesh

var _alive := true
var _current_hp: int
var _t: float = 0.0
var _start_pos: Vector3
var _eliminated := false


func _ready() -> void:
	_current_hp = hp
	_start_pos = position
	if not start_active:
		_set_dormant()


func _process(delta: float) -> void:
	if oscillate and _alive:
		_t += delta * oscillate_speed
		position.x = _start_pos.x + sin(_t) * oscillate_amplitude


func _set_dormant() -> void:
	_alive = false
	collision.disabled = true
	mesh_root.visible = false
	# Couché en attendant l'activation.
	mesh_root.rotation.x = deg_to_rad(-85.0)


## Réveille un ennemi dormant : il apparaît et se redresse (pop-up).
func activate() -> void:
	if _alive or _eliminated:
		return
	_current_hp = hp
	_alive = true
	mesh_root.visible = true
	collision.disabled = false
	var tw := create_tween()
	tw.tween_property(mesh_root, "rotation:x", 0.0, 0.2)


func take_damage(amount: int, _attacker_id: int = 0) -> void:
	if not _alive:
		return
	_current_hp -= amount
	hit_registered.emit(amount)
	if _current_hp <= 0:
		_knockdown()


func _knockdown() -> void:
	_alive = false
	collision.disabled = true
	knocked_down.emit()
	if not _eliminated:
		_eliminated = true
		eliminated.emit()
	var tw := create_tween()
	tw.tween_property(mesh_root, "rotation:x", deg_to_rad(-85.0), 0.15)
	if oneshot:
		return
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func reset() -> void:
	_eliminated = false
	_respawn()


func _respawn() -> void:
	var tw := create_tween()
	tw.tween_property(mesh_root, "rotation:x", 0.0, 0.25)
	await tw.finished
	_current_hp = hp
	_alive = true
	collision.disabled = false
