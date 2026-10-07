# Profil GNOME de référence

## Cible

Le bureau de référence est **Fedora Linux 44 Workstation + GNOME 50 “Tokyo” + Wayland**.

Le projet conserve les composants Fedora/GNOME natifs, Adwaita/libadwaita et Ptyxis comme terminal de référence. Il leur ajoute la **finition fonctionnelle qu'Ubuntu apporte à GNOME** (dock, bureau, tuilage, cohérence des applications GTK3), sans reprendre le thème Yaru, et évite les personnalisations qui compliquent le diagnostic du compositor. Vue d'ensemble : [`GNOME.md`](GNOME.md).

## Extensions gérées et activées

Le profil courant active exactement **six extensions fonctionnelles** dans sa configuration canonique : Dash to Dock, AppIndicator, DING, Show Desktop Plus, Resource Monitor et Tiling Assistant. La couche de finition est activée par défaut ; sa désactivation explicite dans local.conf modifie ce profil.

### Dash to Dock

- paquet : `gnome-shell-extension-dash-to-dock` ;
- source : dépôts Fedora officiels ;
- UUID : `dash-to-dock@micxgx.gmail.com` ;
- activation : `modules/gnome/24_gnome_extensions.sh` ;
- diagnostic : `diagnostics/gnome-doctor`.

La couche gnome.polish applique les réglages déclarés dans config/gnome-polish.conf : dock à gauche, icônes de 48 px, masquage intelligent pour l'écran OLED et clic focus/réduire/aperçus. Les valeurs restent personnalisables dans config/local.conf ; le module et polish-doctor relisent le même état attendu.

### AppIndicator

AppIndicator est activé depuis le paquet Fedora afin de fournir la compatibilité nécessaire aux applications utilisant AppIndicator/KStatusNotifierItem.

Cette extension est **fonctionnelle**, pas cosmétique : son activation évite de perdre des indicateurs/tray attendus par certaines applications professionnelles.

### Desktop Icons NG (DING)

DING est activé depuis l'artefact GNOME Extensions **review `74408` / version de site `95`**, UUID `ding@rastersoft.com`, déclaré compatible GNOME Shell 50.

Fedora 44 ne fournit pas DING comme paquet dans le manifest du projet. L'installateur dédié valide l'URL pinée, l'UUID et la compatibilité GNOME 50, compile le schéma GSettings et conserve un marqueur de provenance.

Son contrat Golden est volontairement minimal :

- `~/Bureau` devient le dossier XDG Desktop ;
- le contenu réel de `~/Bureau` est rendu sur le fond d'écran ;
- la Corbeille est visible ;
- Home, volumes externes et volumes réseau sont masqués afin de ne pas encombrer le bureau.

Il s'agit d'une fonctionnalité de fichiers, pas d'un thème ni d'un effet compositor.

### Show Desktop Plus

Show Desktop Plus est l'extension fonctionnelle dédiée à l'action **Afficher le bureau**.

- UUID : `show-desktop-plus@attentivecoder` ;
- source : GNOME Extensions, review `70326`, version de site `8` ;
- compatibilité exigée : GNOME Shell `50` ;
- position : `left-end` dans la barre supérieure ;
- clic gauche : `toggle-desktop` ;
- raccourci : `Super+D` ;
- badge de fenêtres : désactivé ;
- limitation au moniteur actif : désactivée par défaut.

Le couple DING + Show Desktop Plus forme une seule ergonomie cohérente : afficher le bureau révèle immédiatement `~/Bureau` et la Corbeille, puis l'action inverse restaure les fenêtres du workspace.

### Resource Monitor

Resource Monitor fournit la télémétrie fonctionnelle permanente du HOST.

- UUID : `Resource_Monitor@Ory0n` ;
- source : GNOME Extensions review `70909`, version de site `28` ;
- compatibilité exigée : GNOME Shell `50` ;
- module : `modules/gnome/24b_resource_monitor.sh` ;
- diagnostic : `diagnostics/resource-monitor-doctor` et `diagnostics/gnome-doctor` ;
- rafraîchissement : `2 s` ;
- position : zone droite du panneau.

Affichage Golden :

- CPU : utilisation et température Ryzen (`k10temp`/`Tctl` en priorité) ;
- RAM : pourcentage utilisé ;
- réseau Ethernet/Wi-Fi : débit descendant et montant ; les interfaces inactives sont masquées automatiquement ;
- Intel Arc B580 : charge GPU et température lorsque les sources DRM/sysfs `xe` sont disponibles ;
- disque et swap : volontairement masqués dans le panneau pour garder une lecture compacte.

Le GPU est associé à la cible exacte `8086:e20b`. Sur bare-metal, l'absence de `gpu_busy_percent` ou `gt_busy_percent` est un **KO de télémétrie**, jamais transformé en faux `0 %`. La température GPU hwmon manquante peut rester un WARN si la vraie charge GPU est lisible.

Aucun service root permanent ni collecteur distant n'est introduit par cette extension : les métriques viennent des interfaces kernel, `/proc`, NetworkManager et DRM/sysfs.

### Tiling Assistant

- UUID : tiling-assistant@leleat-on-github ;
- source : release GitHub officielle v55, URL/version/SHA-256 dans config/gnome-extensions.lock ;
- compatibilité exigée : GNOME Shell 50 ;
- module : modules/gnome/24c_ubuntu_polish.sh (gnome.polish) ;
- diagnostic : diagnostics/polish-doctor ;
- usages : quarts d'écran, popup de remplissage et groupes de fenêtres.

Le profil canonique active GNOME_POLISH_ENABLED=true et ENABLE_TILING_ASSISTANT=true. Voir [GNOME_POLISH.md](GNOME_POLISH.md) pour la finition et les réglages OLED.

## Extensions non activées dans l'état Golden

- **Blur My Shell** : désactivé afin de réduire les variables de rendu/compositor à 240 Hz et après suspend/resume ;
- **Just Perfection** : non géré ;
- **Dash to Panel** : non géré ;
- anciennes extensions Desktop Icons : non gérées, DING est l'unique implémentation desktop-icon retenue ;
- **Astra Monitor** : non retenu pour la cible Golden Intel Arc ; Resource Monitor est le backend choisi.

Extension Manager reste disponible comme interface d'administration, sans transformer chaque extension installable en élément du contrat Golden.

## Certification

`diagnostics/gnome-doctor` vérifie les cinq extensions du socle GNOME et appelle également le doctor Resource Monitor. `diagnostics/polish-doctor` vérifie la sixième, Tiling Assistant, sa provenance et les réglages de finition. `gnome-doctor` est appelé par la certification finale ; `polish-doctor` par le diagnostic global workstation-doctor. Exécuter aussi ce dernier avant la qualification pour contrôler la finition.

Les tests CI couvrent séparément :

- absence de faux paquet DING dans le manifest Fedora 44 ;
- téléchargement et validation de l'artefact GNOME-reviewed DING review `74408` / version `95` ;
- téléchargement et validation de l'artefact GNOME-reviewed Show Desktop Plus review `70326` / version `8` ;
- téléchargement et validation de Resource Monitor review `70909` / version `28` ;
- téléchargement et validation de Tiling Assistant v55 depuis la release GitHub officielle ;
- compatibilité GNOME 50 des quatre payloads utilisateur ;
- compilation de leurs schémas GSettings ;
- présence du backend Intel de Resource Monitor et de ses compteurs `gpu_busy_percent`/`gt_busy_percent` ;
- convergence réelle des préférences Resource Monitor dans Fedora 44 ;
- contrat fail-closed du LAB GNOME VirtualBox ;
- activation des six extensions après démarrage, redémarrage et récupération dans le laboratoire Fedora 44.

La validation graphique réelle — icônes effectivement visibles sur le fond d'écran, comportement du bouton avec plusieurs fenêtres et lisibilité de la télémétrie dans le panneau — reste une preuve GNOME runtime et doit être réalisée au **GATE 2 VirtualBox** avec [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md), puis confirmée bare-metal.

La preuve physique des températures Ryzen et de la charge/température B580 appartient exclusivement au GATE 3 bare-metal.

## Règle d'évolution

Toute nouvelle extension doit :

1. apporter un besoin fonctionnel clairement identifié ;
2. être compatible GNOME 50 ;
3. provenir d'une source gérée ;
4. être testée par rapport à l'état GNOME certifié ;
5. ne pas masquer une régression Mutter/Wayland/GPU.

Voir aussi [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md), [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md) et [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).
