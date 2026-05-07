extends Node
## OpenXRSetup — initialise OpenXR à l'ouverture de la scène d'arène.
## À attacher en autoload OU comme node fils du root de l'arène.

@export var maximum_refresh_rate: int = 90

var xr_interface: XRInterface


func _ready() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		print("[XR] OpenXR initialisé")
		# Désactive le V-Sync (le compositeur XR gère le timing)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		# Bascule le viewport principal en mode XR
		get_viewport().use_xr = true
		# Tente de set le refresh rate maximum dispo
		_set_best_refresh_rate()
	else:
		push_warning("[XR] OpenXR introuvable / non initialisé. " +
				"Le jeu va tourner en mode écran (utile pour debug en éditeur).")


func _set_best_refresh_rate() -> void:
	if xr_interface == null:
		return
	# Sur Quest 2/3, les refresh rates dispo sont 72/80/90/120 Hz selon le casque.
	if xr_interface.has_method("get_available_display_refresh_rates"):
		var rates: Array = xr_interface.get_available_display_refresh_rates()
		var best := 0.0
		for r in rates:
			if r <= maximum_refresh_rate and r > best:
				best = r
		if best > 0:
			xr_interface.set_display_refresh_rate(best)
			print("[XR] Refresh rate réglé à %s Hz" % best)
