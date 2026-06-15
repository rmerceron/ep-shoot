extends Node3D
## Menu VR solo — START (parcours) ou TRAINING (stand de tir libre).
## Interaction via VRPointer (laser sur le contrôleur droit).

@export var course_scene_path: String = "res://scenes/Course.tscn"
@export var training_scene_path: String = "res://scenes/Training.tscn"

@onready var status_label: Label3D = $StatusLabel
@onready var btn_start: Area3D = $BtnStart
@onready var btn_training: Area3D = $BtnTraining
@onready var pointer: Node = $XROrigin3D/RightController/VRPointer


func _ready() -> void:
	if pointer:
		pointer.pointer_clicked.connect(_on_pointer_clicked)
	# Fallback souris pour debug en éditeur sans casque.
	btn_start.input_event.connect(_on_btn_input.bind("start"))
	btn_training.input_event.connect(_on_btn_input.bind("training"))


func _on_pointer_clicked(area: Area3D) -> void:
	if area == btn_start:
		_handle_action("start")
	elif area == btn_training:
		_handle_action("training")


func _on_btn_input(_camera, event: InputEvent, _pos, _normal, _idx, action: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		_handle_action(action)


func _handle_action(action: String) -> void:
	match action:
		"start":
			status_label.text = "Lancement du parcours..."
			get_tree().change_scene_to_file(course_scene_path)
		"training":
			status_label.text = "Lancement entraînement..."
			get_tree().change_scene_to_file(training_scene_path)
