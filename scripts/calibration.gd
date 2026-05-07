extends Node3D
## Calibration — alignement des deux casques sur un repère physique commun.
##
## PROBLÈME : chaque Quest a sa propre origine de "guardian" et son propre
## "recenter". Si les deux joueurs lancent le jeu, leurs origines virtuelles
## (0,0,0) ne correspondent PAS au même point physique. Sans calibration,
## un joueur qui voit son adversaire à 2m devant lui peut être physiquement
## à côté de lui (collision réelle) ou à l'autre bout de la pièce.
##
## SOLUTION (la plus simple, sans ARCore/ARKit anchors) :
## 1. Avant le match, pose physiquement un objet (scotch sur le sol, livre,
##    pied de table) au centre de votre zone de jeu.
## 2. Chaque joueur va se placer juste au-dessus de ce repère, le contrôleur
##    droit pointé vers le mur "nord" choisi (ex : la fenêtre).
## 3. Chaque joueur appuie sur la gâchette droite. Le script enregistre la
##    position et l'orientation du contrôleur, puis calcule la transformée
##    inverse à appliquer à l'XROrigin3D pour que ce point physique corresponde
##    à (0,0,0) virtuel avec l'axe -Z = "nord".
##
## Une fois les deux joueurs calibrés sur le même repère physique, leurs
## espaces virtuels sont alignés : se retrouver à 2m face à face en virtuel
## = se retrouver à 2m face à face en physique. Ce qui veut dire qu'ils
## DOIVENT faire attention à ne pas se cogner.

signal calibration_done(offset: Transform3D)

@export var controller_path: NodePath
@export var origin_path: NodePath

@onready var controller: XRController3D = get_node_or_null(controller_path)
@onready var origin: XROrigin3D = get_node_or_null(origin_path)

var _waiting_for_input := false


func start_calibration() -> void:
	_waiting_for_input = true
	if controller:
		controller.button_pressed.connect(_on_button_pressed)
	print("[CAL] En attente : place ton contrôleur droit sur le repère " +
			"physique, pointe vers le mur nord, et appuie sur la gâchette.")


func _on_button_pressed(button_name: String) -> void:
	if not _waiting_for_input:
		return
	if button_name != "trigger_click" and button_name != "trigger":
		return
	_waiting_for_input = false
	if controller:
		controller.button_pressed.disconnect(_on_button_pressed)
	_apply_calibration()


func _apply_calibration() -> void:
	# La position+orientation actuelle du contrôleur doit devenir l'origine.
	# On construit la transformée inverse, en aplatissant la rotation au
	# yaw uniquement (on ne veut pas tordre l'horizon en cas de roll/pitch).
	var ctrl_xform: Transform3D = controller.transform
	var pos := ctrl_xform.origin
	# Yaw uniquement
	var fwd := -ctrl_xform.basis.z
	fwd.y = 0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var yaw := atan2(fwd.x, fwd.z)
	# On veut que (pos, yaw) soit la nouvelle origine -> applique la transfo
	# inverse à l'origin XR.
	var calibrated_basis := Basis(Vector3.UP, -yaw)
	var calibrated_xform := Transform3D(calibrated_basis, calibrated_basis * -pos)
	# Note : on ne touche pas à Y (hauteur), le casque garde sa hauteur réelle.
	calibrated_xform.origin.y = 0
	if origin:
		origin.transform = calibrated_xform
	GameState.calibration_offset = calibrated_xform
	print("[CAL] Calibration appliquée : offset = %s" % calibrated_xform)
	calibration_done.emit(calibrated_xform)
