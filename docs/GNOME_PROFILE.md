# Profil GNOME de référence

## Cible

Le bureau de référence est **Fedora Linux 44 Workstation + GNOME 50 “Tokyo” + Wayland**.

Le projet conserve les composants Fedora/GNOME natifs, Adwaita/libadwaita et Ptyxis comme terminal de référence. Il ne cherche pas à reproduire Ubuntu/Yaru et évite les personnalisations qui compliquent le diagnostic du compositor.

## Extensions gérées et activées

Le profil courant active exactement **quatre extensions fonctionnelles**.

### Dash to Dock

- paquet : `gnome-shell-extension-dash-to-dock` ;
- source : dépôts Fedora officiels ;
- UUID : `dash-to-dock@micxgx.gmail.com` ;
- activation : `modules/gnome/24_gnome_extensions.sh` ;
- diagnostic : `diagnostics/gnome-doctor`.

Le projet conserve les préférences Fedora/upstream tant qu'une décision explicite n'est pas versionnée. Position, taille, autohide, opacité et animations ne sont donc pas arbitrairement forcées.

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

## Extensions non activées dans l'état Golden

- **Blur My Shell** : désactivé afin de réduire les variables de rendu/compositor à 240 Hz et après suspend/resume ;
- **Just Perfection** : non géré ;
- **Dash to Panel** : non géré ;
- anciennes extensions Desktop Icons : non gérées, DING est l'unique implémentation desktop-icon retenue.

Extension Manager reste disponible comme interface d'administration, sans transformer chaque extension installable en élément du contrat Golden.

## Certification

`diagnostics/gnome-doctor` fait partie de la certification finale et vérifie les quatre extensions fonctionnelles. Pour la couche ergonomie, il vérifie aussi les réglages DING, le dossier XDG Desktop, la provenance des deux extensions utilisateur et les paramètres du bouton/raccourci.

Les tests CI couvrent séparément :

- absence de faux paquet DING dans le manifest Fedora 44 ;
- téléchargement et validation de l'artefact GNOME-reviewed DING review `74408` / version `95` ;
- téléchargement et validation de l'artefact GNOME-reviewed Show Desktop Plus review `70326` / version `8` ;
- compatibilité GNOME 50 des deux payloads ;
- compilation de leurs schémas GSettings ;
- convergence réelle des préférences DING/Show Desktop dans un utilisateur Fedora de test ;
- contrat fail-closed du LAB GNOME VirtualBox.

La validation graphique réelle — icônes effectivement visibles sur le fond d'écran et comportement du bouton avec plusieurs fenêtres — reste une preuve GNOME runtime et doit être réalisée au **GATE 2 VirtualBox** avec [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md), puis confirmée bare-metal.

## Règle d'évolution

Toute nouvelle extension doit :

1. apporter un besoin fonctionnel clairement identifié ;
2. être compatible GNOME 50 ;
3. provenir d'une source gérée ;
4. être testée par rapport à l'état GNOME certifié ;
5. ne pas masquer une régression Mutter/Wayland/GPU.

Voir aussi [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md), [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md) et [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).
