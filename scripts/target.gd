extends AnimatableBody3D
## Target — cible tirable. Deux modes :
##  - mode "knockdown" (default) : tombe quand HP <= 0, se relève après un délai
##  - mode "oneshot" : reste tombée (utile pour boutons d'action genre RESET)
##
## Optionnellement oscille horizontalement (cible mobile).
##
## Émet `hit_registered(damage)` sur tir, et `knocked_down()` à la chute.
## Hiérarchie : AnimatableBody3D + CollisionShape3D + Mesh (Node3D contenant
## la géométrie qui sera animée).

signal hit_registered(damage: int)
signal knocked_down

@export var hp: int = 1
@export var respawn_delay: float = 2.0
@export var oneshot: bool = false
@export var oscillate: bool = false
@export var oscillate_amplitude: float = 1.5
@export var oscillate_speed: float = 1.0

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var mesh_root: Node3D = $Mesh

var _alive := true
var _current_hp: int
var _t: float = 0.0
var _start_pos: Vector3


func _ready() -> void:
	_current_hp = hp
	_start_pos = position


func _process(delta: float) -> void:
	if oscillate and _alive:
		_t += delta * oscillate_speed
		position.x = _start_pos.x + sin(_t) * oscillate_amplitude


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
	# Bascule la géométrie en arrière (rotation X)
	var tw := create_tween()
	tw.tween_property(mesh_root, "rotation:x", deg_to_rad(-85.0), 0.15)
	if oneshot:
		return
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func reset() -> void:
	# Force le respawn (utilisé par le bouton RESET)
	_respawn()


func _respawn() -> void:
	var tw := create_tween()
	tw.tween_property(mesh_root, "rotation:x", 0.0, 0.25)
	await tw.finished
	_current_hp = hp
	_alive = true
	collision.disabled = false
