# EP-Shoot — VR FPS solo (Quest 2/3 standalone)

Mini-jeu VR Godot 4.6 : un **parcours de tir solo**. Le joueur traverse un
couloir au joystick et élimine toutes les cibles le long du trajet, façon
mission d'intro / stand de tir de Call of Duty. Chrono au compteur : termine le
parcours le plus vite possible.

> **Changement de cap** : le projet était au départ un duel 1v1 en réseau entre
> deux casques dans la même pièce. Comme on ne peut pas connecter deux Meta
> Quest sur un seul PC, on est passé en **solo**. Tout le code réseau
> (`network_manager.gd`), la calibration deux casques (`calibration.gd`) et
> l'arène multi (`Arena.tscn`) ont été retirés.

## Ce qui est dans ce repo

```
ep-shoot/
├── project.godot           # config Godot (OpenXR + Forward Mobile), 1 autoload : GameState
├── scenes/
│   ├── Menu.tscn           # menu d'entrée : START (parcours) / TRAINING (stand libre)
│   ├── Course.tscn         # LE parcours : couloir + couvertures + 4 vagues d'ennemis
│   ├── Training.tscn       # stand de tir libre (test des armes)
│   ├── Player.tscn         # joueur VR (XROrigin + 2 contrôleurs + arme)
│   ├── Weapon.tscn         # arme placeholder (cube + tracer)
│   ├── Target.tscn         # cible/ennemi tirable
│   └── VRPointer.tscn      # laser pointer pour les menus
├── scripts/
│   ├── game_state.gd       # autoload : cibles restantes, chrono, fin, combo de précision
│   ├── openxr_setup.gd     # init OpenXR + refresh rate Quest
│   ├── menu.gd             # logique du menu
│   ├── course.gd           # parcours : spawn joueur, vagues, HUD, écran de fin
│   ├── training.gd         # stand de tir libre
│   ├── player.gd           # joueur VR + locomotion joystick + snap-turn
│   ├── weapon.gd           # tir raycast + dégâts directs
│   ├── target.gd           # cible : pop-up, knockdown, signal d'élimination
│   └── vr_pointer.gd       # laser pointer
└── assets/                 # à remplir (cf. Weapon System asset)
```

## Gameplay

### Contrôles (manettes Quest)

- **Stick gauche** : se déplacer (avant/arrière/strafe), relatif au regard.
- **Stick droit (gauche/droite)** : rotation par paliers (snap-turn, confort VR).
- **Gâchette droite** : tirer (un laser de visée part du canon). Enchaîne les
  touches sans rater pour faire grimper le **combo** et accélérer.
- **A / X** : recommencer le parcours à tout moment.
- **B / Y** : revenir au menu à tout moment.
- Dans les menus : pointe avec le **laser** (contrôleur droit) et tire.

Les réglages de locomotion sont exposés sur `Player.tscn` (inspector du nœud
racine `Player`) : `move_speed`, `snap_turn_degrees`, `gravity`, deadzones.

### Le parcours (Course.tscn)

1. Au menu, tire sur **START** (vert).
2. Tu démarres en haut d'un couloir d'environ 50 m. Le chrono se lance.
3. Avance au stick. Les ennemis sont organisés en **4 vagues** :
   - La 1ʳᵉ vague est déjà debout près du départ.
   - Les suivantes sont **couchées** et se relèvent (pop-up) quand tu franchis
     une **zone de déclenchement** invisible en avançant.
4. Quelques **caisses** servent de couverture / décor.
5. Élimine **toutes** les cibles (14 au total) pour terminer. Le HUD ancré
   devant toi affiche `Cibles : x / 14` et le temps.
6. À la fin, un panneau **PARCOURS TERMINÉ** affiche ton temps. Les boutons
   **RESTART** (bleu) et **EXIT** (orange) apparaissent alors au mur du fond —
   ils restent **cachés pendant le parcours** pour éviter de tirer dessus par
   erreur. Tire dessus, ou utilise les raccourcis manette **A/X** (recommencer)
   et **B/Y** (quitter), disponibles à tout moment.

### Le mode entraînement (Training.tscn)

Stand de tir libre pour tester les armes : silhouettes fixes + une cible mobile,
boutons RESET / EXIT tirables. Les cibles s'y relèvent automatiquement après 2s.

### Combo de précision (récompense l'accuracy)

Chaque tir qui **touche une cible** augmente le combo : **+10 % de vitesse de
déplacement par palier**, plafonné à **+100 %** (combo 10 = vitesse ×2). Tout
tir qui **ne touche pas de cible** — tir dans le vide, dans un mur ou une
caisse — **remet le combo à zéro**. Plus tu es précis et rapide, plus tu te
déplaces vite : la précision est directement récompensée par le chrono.

Le combo s'affiche au HUD (couleur qui passe du bleu au orange selon
l'intensité). Réglages dans `game_state.gd` : `SPEED_STEP` (bonus par palier)
et `COMBO_MAX` (plafond). Les boutons RESTART/EXIT ne comptent pas dans le combo.

## Comment c'est construit (pour itérer)

- **`game_state.gd`** (autoload) tient l'état d'un parcours : `total_targets`,
  `eliminated`, `elapsed`, `course_active`. `start_course(total)` au départ,
  `register_kill()` à chaque élimination, signal `course_finished(temps)` quand
  tout est à terre.
- **`target.gd`** : chaque cible est un `AnimatableBody3D`. En parcours elle est
  en `oneshot = true` (reste à terre une fois tuée) et émet `eliminated`. Une
  cible de vague démarre `start_active = false` (couchée + collision off) puis
  est réveillée par `activate()` avec un effet de redressement.
- **`course.gd`** recense les ennemis via le **groupe `enemy`**, connecte leur
  signal `eliminated`, et réveille une vague quand le joueur entre dans une
  `Area3D` du **groupe `wave_trigger`** (tous les ennemis enfants du parent du
  trigger sont activés, une seule fois).

### Ajouter / modifier des ennemis

Dans `Course.tscn`, sous `Enemies/WaveN` :

- Duplique une instance de `Target.tscn`, place-la, garde-la dans le groupe
  `enemy` et coche `oneshot`. Pour qu'elle apparaisse seulement quand on
  atteint la vague, mets `start_active = false`.
- Pour une vague entièrement nouvelle : crée un `Node3D WaveN`, ajoute dedans
  une `Area3D` (groupe `wave_trigger`) avec un `CollisionShape3D` (boîte large
  qui barre le couloir), puis les ennemis `start_active = false`.
- Rends une cible mobile avec `oscillate = true` + `oscillate_amplitude` /
  `oscillate_speed`.

Le compteur total s'ajuste automatiquement (compte des nœuds du groupe `enemy`).

## Pré-requis (export Quest)

À installer **dans cet ordre** :

1. **Godot 4.6+** ([godotengine.org](https://godotengine.org/download)).
2. **Modèles d'exportation génériques** :
   `Éditeur → Gérer les modèles d'exportation... → Télécharger et installer`.
3. **Android SDK + JDK 17** (le plus simple : Android Studio, qui fournit le SDK
   + `platform-tools` avec `adb`). Puis dans Godot :
   `Éditeur → Paramètres de l'éditeur → Exportation → Android` → renseigner
   `Android SDK Path` et `Debug Keystore` (Godot peut le générer).
4. **Plugin OpenXR Vendors (Meta Quest)** : `AssetLib` → `Godot OpenXR Vendors`
   → installer dans le projet (fournit le préset d'export Meta Quest).
5. **Modèle de compilation Android** : `Projet → Installer un modèle de
   compilation Android...` (différent du point 2 : c'est un template spécifique
   au projet, indispensable pour inclure le plugin OpenXR Vendors dans l'APK).
6. **ADB** (dans `platform-tools`) pour pousser l'APK.
7. **Asset Weapon System** ([asset 4105](https://godotengine.org/asset-library/asset/4105))
   — optionnel, à intégrer plus tard.

> **À retenir** : les *modèles d'exportation* (point 2) sont globaux à l'éditeur.
> Le *modèle de compilation Android* (point 5) est spécifique au projet et
> nécessaire dès qu'on utilise un plugin natif comme OpenXR Vendors.

## Premier lancement (en éditeur, sans casque)

1. Ouvre `project.godot` dans Godot 4.6.
2. À la première ouverture, Godot regénère les UID des `.tscn` / `.gd`. Si un
   import se plaint, ouvre chaque scène une fois puis sauvegarde.
3. F5 : le menu s'affiche en mode écran (la caméra XR devient une caméra
   classique tant qu'OpenXR n'est pas initialisé).
4. Sans casque, le test reste limité (pas de tracking ni de sticks), mais tu
   peux vérifier que les scènes chargent et cliquer les boutons du menu à la
   souris (fallback `input_event`).

## Build APK pour Quest

Une fois le plugin Meta Quest installé via AssetLib :

1. `Project → Export...`
2. `Add → Meta Quest` (préset fourni par le plugin).
3. Renseigner :
   - `Application → Package → Unique Name` = `com.tonnom.epshoot`
   - `Architectures → arm64-v8a` ✓ (les autres décochés)
   - `XR Features → XR Mode = OpenXR`
   - `XR Features → Hand Tracking = Optional`
4. Casque en mode développeur, branché en USB, accepte la popup ADB.
5. `Export Project (Debug)` → `epshoot.apk`, puis :
   ```bash
   adb install -r epshoot.apk
   ```
   Ou `Project → Remote Debug → One-click Deploy` (build + install + lance +
   logs dans la console Godot).

## Intégrer l'asset Weapon System (asset 4105)

L'asset n'est **pas VR-ready** par défaut (raycast depuis la caméra, pas le
contrôleur). Pour l'utiliser :

1. AssetLib → installer `Weapon System` dans `assets/`.
2. Dans `scenes/Weapon.tscn`, remplace le `Mesh` placeholder (BoxMesh) par le
   modèle d'arme.
3. **Garde le `Muzzle`** (Node3D) au bout du canon — c'est l'origine du raycast
   dans `weapon.gd`.
4. Pour les animations / sons, expose-les comme méthodes et appelle-les dans
   `_perform_shot()` (ex. `$AnimationPlayer.play("fire")`, un
   `AudioStreamPlayer3D` déclenché au tir).

Ne se transposent **pas** en VR : crosshair écran, ADS écran, bobbing caméra —
en VR tu vises avec ton bras.

## Confort VR

- La locomotion stick peut donner le mal des transports : `move_speed` est
  volontairement bas (2.5 m/s) et la rotation est en **snap-turn** (paliers) et
  non continue. Ajuste `snap_turn_degrees` selon ton confort.
- Définis une zone Guardian suffisante : même si on se déplace au stick, tu peux
  faire quelques pas physiques.

## TODO / pistes pour la suite

- [ ] Vignette de confort (assombrissement périphérique) pendant le déplacement.
- [ ] Option locomotion continue vs snap-turn dans un menu d'options.
- [ ] Score basé aussi sur la précision (tirs touchés / tirs tirés).
- [ ] Ennemis qui ripostent + barre de vie (mode "survie").
- [ ] Effets : muzzle flash, particules d'impact, son 3D positionnel.
- [ ] Plusieurs parcours / niveaux et un classement des meilleurs temps.
- [ ] Vraie intégration de l'asset Weapon System avec rechargement.
- [ ] Mains animées (doigts selon `grip` + `trigger`).

## Debug

- Logs Godot ↔ Quest : `adb logcat -s godot`.
- Si OpenXR ne s'init pas sur le casque : vérifier que le préset Meta Quest est
  sélectionné à l'export et que `XR Mode = OpenXR`.
