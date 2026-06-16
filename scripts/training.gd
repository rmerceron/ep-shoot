extends Node3D
## Training — mode entraînement solo libre (stand de tir). Pas de réseau.
## Spawn le joueur, compte les hits, boutons RESET / EXIT tirables.

@export var player_scene: PackedScene
@export var spawn_path: NodePath
@export var menu_scene_path: String = "res://scenes/Menu.tscn"

@onready var spawn: Node3D = get_node_or_null(spawn_path)
@onready var hit_label: Label3D = $HUD/HitLabel
@onready var time_label: Label3D = $HUD/TimeLabel
@onready var btn_reset = $BtnReset
@onready var btn_exit = $BtnExit
@onready var targets_root: Node = $Targets

var hits: int = 0
var elapsed: float = 0.0


func _ready() -> void:
	GameState.reset_combo()
	if player_scene:
		var p: Node = player_scene.instantiate()
		add_child(p)
		if spawn:
			p.global_position = spawn.global_position

	for t in targets_root.get_children():
		if t.has_signal("hit_registered"):
			t.hit_registered.connect(_on_target_hit)

	if btn_reset:
		btn_reset.knocked_down.connect(_reset)
	if btn_exit:
		btn_exit.knocked_down.connect(_exit_to_menu)

	_update_hud()


func _process(delta: float) -> void:
	elapsed += delta
	if time_label:
		time_label.text = "Temps : %.1fs" % elapsed


func _on_target_hit(_amount: int) -> void:
	hits += 1
	_update_hud()


func _update_hud() -> void:
	if hit_label:
		hit_label.text = "Hits : %d" % hits


func _reset() -> void:
	hits = 0
	elapsed = 0.0
	for t in targets_root.get_children():
		if t.has_method("reset"):
			t.reset()
	if btn_reset and btn_reset.has_method("reset"):
		btn_reset.reset()
	_update_hud()


func _exit_to_menu() -> void:
	get_tree().change_scene_to_file(menu_scene_path)
