# EP-Shoot — VR FPS 1v1 (Quest 2/3 standalone)

Mini-jeu VR Godot 4.6 : duel à l'arme à feu en local entre deux Quest 2/3, dans
la **même pièce physique**, en réseau Wi-Fi local (ENet).

## Ce qui est dans ce repo

```
ep-shoot/
├── project.godot           # config Godot (OpenXR + Forward Mobile)
├── scenes/
│   ├── Menu.tscn           # menu Host / Join (entrée du jeu)
│   ├── Arena.tscn          # arène 8x8m avec murs + spawn points
│   ├── Player.tscn         # joueur VR (XROrigin + 2 contrôleurs + arme)
│   └── Weapon.tscn         # arme placeholder (cube + tracer)
├── scripts/
│   ├── game_state.gd       # autoload : score, calibration_offset
│   ├── network_manager.gd  # autoload : ENet host/client
│   ├── openxr_setup.gd     # init OpenXR + refresh rate Quest
│   ├── menu.gd             # logique du menu
│   ├── arena.gd            # spawn des joueurs, HUD score
│   ├── player.gd           # logique joueur (HP, RPC dégâts, sync)
│   ├── weapon.gd           # tir raycast + dégâts via RPC
│   └── calibration.gd      # alignement du repère physique partagé
└── assets/                 # à remplir (cf. Weapon System asset)
```

## Pré-requis

À installer **dans cet ordre** :

1. **Godot 4.6+** (téléchargé depuis [godotengine.org](https://godotengine.org/download)).

2. **Modèles d'exportation génériques** :
   `Éditeur → Gérer les modèles d'exportation... → Télécharger et installer`.
   Ce sont les binaires moteur pour toutes les plateformes (~1 Go, en une fois).

3. **Android SDK + JDK 17** : le plus simple est d'installer Android Studio,
   ça te donne le SDK + `platform-tools` (qui contient `adb`).
   Puis dans Godot : `Éditeur → Paramètres de l'éditeur → Exportation → Android`
   et renseigner les chemins :
   - `Android SDK Path`
   - `Debug Keystore` (Godot peut le générer automatiquement la première fois)

4. **Plugin OpenXR Vendors (Meta Quest)** : dans Godot,
   `AssetLib` → recherche `Godot OpenXR Vendors` → installer dans le projet.
   Ce plugin fournit le préset d'export Meta Quest, les permissions VR et
   l'AAR natif nécessaire.

5. **Modèle de compilation Android** : `Projet → Installer un modèle de
   compilation Android...` (à NE PAS confondre avec le point 2 — c'est un
   second template, spécifique au projet, qui crée un dossier `android/build/`
   avec un build Gradle custom). **Indispensable** pour que le plugin OpenXR
   Vendors soit inclus dans l'APK.

6. **ADB** (livré avec `platform-tools` du SDK Android) pour pousser l'APK
   sur les casques.

7. **Asset Weapon System** ([asset-library/asset/4105](https://godotengine.org/asset-library/asset/4105))
   — à intégrer plus tard (cf. section "Intégrer l'asset Weapon System").

> **À retenir** : il y a deux notions de "templates" en Godot. Les *modèles
> d'exportation* (point 2) sont génériques et globaux à l'éditeur. Le *modèle
> de compilation Android* (point 5) est spécifique au projet et nécessaire dès
> que tu utilises un plugin Android natif comme OpenXR Vendors. Sans le point
> 5, l'export Quest avec OpenXR ne marche pas.

## Premier lancement (en éditeur, sans casque)

1. Ouvre `project.godot` dans Godot 4.6.
2. La première import va se plaindre que les UID `b1weapon`, `b1playervr`, etc.
   ne sont pas trouvés. **C'est normal** : à la première ouverture, Godot
   regénère les UIDs des `.tscn`. Si ça casse, ouvre chaque `.tscn` une fois
   dans l'éditeur pour qu'il les régénère, puis sauvegarde.
3. F5 : tu vas voir le menu en mode écran (la caméra XR se transforme en caméra
   classique car OpenXR n'est pas init).
4. En mode éditeur tu ne peux pas tester le multi VR end-to-end. Mais tu peux :
   - vérifier que les scènes chargent
   - tester le réseau en lançant deux instances Godot (l'une "Host", l'autre "Join 127.0.0.1")

## Build APK pour Quest

Une fois le plugin Meta Quest installé via AssetLib :

1. `Project → Export...`
2. `Add → Meta Quest` (préset fourni par le plugin)
3. Renseigner :
   - `Application → Package → Unique Name` = `com.tonnom.epshoot`
   - `Architectures → arm64-v8a` ✓ (les autres décochés)
   - `XR Features → XR Mode = OpenXR`
   - `XR Features → Hand Tracking = Optional`
4. Met le casque en mode développeur (compte Meta dev → activer dev mode dans
   l'app Meta sur ton tel → réinitialiser le casque), branche-le en USB,
   accepte la popup ADB.
5. `Export Project (Debug)` → `epshoot.apk`
6. Pousser sur le casque :
   ```bash
   adb install -r epshoot.apk
   ```
   Ou plus simple : `Project → Remote Debug → One-click Deploy` quand le
   casque est connecté en ADB. Ça build, installe, lance, et redirige les
   logs dans la console Godot.

Répète pour le 2e casque.

## Lancement d'une partie

### Réseau

Les deux Quest doivent être sur le **même Wi-Fi**. Quel que soit le routeur,
l'idée est :

1. Joueur A lance le jeu, choisit `HOST` → un serveur ENet écoute sur le port 8910.
2. Joueur A regarde l'IP locale de son Quest :
   - dans le casque : `Settings → Wi-Fi → (réseau) → Advanced → IP Address`
3. Joueur B lance le jeu, l'IP par défaut est `127.0.0.1` — il faut la
   remplacer par celle de A. Pour l'instant l'IP est en dur dans `menu.gd`
   (variable `ip_text`). À itérer : ajouter un keyboard 3D ou un système
   de découverte UDP broadcast.
4. Joueur B clique `JOIN`.

### Calibration de l'espace partagé (IMPORTANT)

Sans calibration, vos deux mondes virtuels ne sont **pas alignés** : vous
risquez de vous voir à un endroit alors que physiquement vous êtes ailleurs.
Procédure :

1. **Posez physiquement un repère** au centre de la pièce : une feuille
   scotchée au sol, un livre, n'importe quoi de visible et stable.
2. Choisissez ensemble une **direction "nord"** (ex : vers la fenêtre).
3. À tour de rôle, chaque joueur :
   - se place pile au-dessus du repère
   - pose le contrôleur droit sur le repère, pointé vers le nord
   - appuie sur la **gâchette droite**
4. Le script `calibration.gd` enregistre la transformée et l'applique au
   `XROrigin3D`. À partir de là, vos deux mondes sont alignés.

Pour l'instant la calibration se déclenche automatiquement quand le joueur
local entre dans l'arène — à toi d'ajouter une UI pour la relancer si besoin
(`Calibration.start_calibration()`).

### Sécurité physique

**Vous êtes dans la même pièce physique avec des casques opaques sur la tête.**
Quelques règles :

- Délimitez la zone (une vraie zone Guardian sur chaque casque, ~3x3m mini).
- Posez le canapé / la table / les chaises hors de la zone.
- Pour cette V0, **interdiction de courir**. Faites des duels lents.
- Si ton arme est dans ta main droite, ton adversaire visera ta poitrine.
  Vous risquez de vous taper dans les contrôleurs. Évitez le corps-à-corps.

## Intégrer l'asset Weapon System (asset 4105)

L'asset `Weapon System` est conçu pour un FPS clavier/souris. Il fournit un
gestionnaire d'inventaire d'armes, des animations, des sons. Il **n'est pas
VR-ready** par défaut : son raycast part de la caméra du joueur, pas du
contrôleur.

Étapes pour l'intégrer proprement :

1. AssetLib dans Godot → installer `Weapon System` (asset 4105) dans `assets/`.
2. Récupère le mesh / animations / sons d'une arme qui te plaît.
3. Dans `scenes/Weapon.tscn`, remplace le `Mesh` placeholder (BoxMesh) par
   l'instance du modèle d'arme.
4. Garde le `Muzzle` (Node3D) au bout du canon de la nouvelle arme — c'est lui
   qui sert d'origine du raycast dans `weapon.gd`.
5. Si tu veux les animations de tir / recul, expose-les comme méthodes et
   appelle-les depuis `weapon.gd` dans `_perform_shot()` :
   ```gdscript
   if has_node("AnimationPlayer"):
       $AnimationPlayer.play("fire")
   ```
6. Pour le son de tir, ajoute un `AudioStreamPlayer3D` dans `Weapon.tscn`
   et déclenche-le dans `_perform_shot()`.

**Ce qui ne se transpose PAS depuis l'asset** : le système de visée (crosshair
écran), le ADS (aim-down-sights écran), le bobbing caméra. En VR ces concepts
n'existent pas — tu vises avec ton bras, point.

## Architecture réseau

- **ENetMultiplayerPeer** en mode peer-to-peer.
- Host = peer 1 (autorité du match, score, spawn).
- Client = peer 2 (autorité de son propre joueur via `set_multiplayer_authority`).
- **Synchronisation des transformées** via `MultiplayerSynchronizer` dans
  `Player.tscn` (replication mode 1 = sur changement, à chaque frame physique).
- **Dégâts** via RPC : le tireur appelle `Player.take_damage.rpc_id(targetAuthority, ...)`
  — c'est le joueur touché qui décrémente sa propre HP (autorité de soi-même).
  Le tueur reçoit le score via `GameState.add_score.rpc(killer_id)`.

Cette approche est simple mais pas anti-triche : un client malveillant peut
mentir sur sa position. Pour ce contexte (deux potes dans le même salon),
c'est OK.

## TODO / pistes pour la suite

- [ ] Clavier 3D pour saisir l'IP au lieu de la valeur en dur.
- [ ] Découverte LAN automatique (UDP broadcast) pour éviter de taper l'IP.
- [ ] UI de calibration explicite (bouton "Calibrer", feedback visuel).
- [ ] Mesh main avec doigts qui s'animent selon les inputs (`grip` + `trigger`).
- [ ] Locomotion stick (optionnelle) pour la variante "arène plus grande".
- [ ] Avatar du joueur distant : actuellement c'est juste les 3 cubes (tête +
      2 mains). Ajouter un body IK simple (épaules + tête).
- [ ] Effets : muzzle flash, particles d'impact, son 3D positionnel.
- [ ] Modes de jeu : best-of-N, time attack, last man standing.
- [ ] Vraie intégration de l'asset Weapon System avec switch d'armes.
- [ ] Hitbox plus précise que la capsule (tête + torse séparés pour headshots).

## Debug

- Logs Godot ↔ Quest : `adb logcat -s godot` (filtre les logs du jeu).
- Si OpenXR ne s'init pas sur le casque : check que le préset Meta Quest est
  bien sélectionné à l'export et que `XR Mode = OpenXR`.
- Si le réseau ne se connecte pas : check que les deux Quest sont sur le même
  SSID, et que le routeur n'isole pas les clients (option "AP Isolation" / 
  "Client Isolation" doit être OFF).
