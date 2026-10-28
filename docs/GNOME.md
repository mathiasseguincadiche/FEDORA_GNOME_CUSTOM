# Le bureau GNOME

Fedora livre GNOME tel que ses développeurs l'ont conçu : propre, mais dépouillé. Le projet garde ce GNOME officiel (GNOME 51 sur Fedora 45, Wayland, Adwaita/libadwaita, applications Fedora) et lui ajoute **l'ergonomie qu'Ubuntu apporte à GNOME**, sans son thème Yaru ni ses icônes ([ADR 0013](adr/0013-ubuntu-grade-gnome-polish.md)).

Le profil Fedora 45 reste `pending` tant que le média final signé et les composants stables n'ont pas été promus ([fiche Fedora 45](FEDORA45_PRIMARY.md)).

## Ce que tu obtiens

| Avant (Fedora pur) | Après | Pourquoi |
|---|---|---|
| Dock visible seulement dans Activités | Dock **à gauche, pleine hauteur**, masqué dès qu'une fenêtre le recouvre (*intellihide*) | lancer et basculer en un clic, sans marquer l'écran OLED |
| Session ouverte sur Activités | Session ouverte **sur le bureau**, icônes et Corbeille visibles | retrouver tout de suite ses fichiers |
| Clic sur une app ouverte : rien de plus | Clic = focus, re-clic = réduire, plusieurs fenêtres = aperçus | comportement de barre de tâches |
| Tuilage gauche/droite | **Tiling Assistant** : quarts d'écran, remplissage, groupes | l'« Enhanced Tiling » d'Ubuntu |
| Accent bleu | Accent **orange** (configurable) | identité proche d'Ubuntu |
| Apps GTK3 (LibreOffice, FileZilla…) au look ancien | Look moderne **adw-gtk3**, clair et sombre | cohérence visuelle |
| Pas de boutons réduire/agrandir | `:minimize,maximize,close` à droite | habitude Windows/Ubuntu |
| Horloge sans jour | Jour de la semaine, nouvelles fenêtres centrées | confort |

## Les six extensions

Chaque extension remplit une fonction précise. Les identités et archives exactes sont épinglées ; ce ne sont pas des options de `config/local.conf`.

| Rôle | Extension / UUID | Source épinglée |
|---|---|---|
| Dock | Dash to Dock / `dash-to-dock@micxgx.gmail.com` | RPM Fedora, version exacte dans `profiles/fedora45/gnome-rpms.json` |
| Indicateurs d'applications | AppIndicator / `appindicatorsupport@rgcjonas.gmail.com` | RPM Fedora, même verrou |
| Bureau et Corbeille | Gtk4 Desktop Icons NG / `gtk4-ding@smedius.gitlab.com` | version 145, review 75162 |
| Afficher le bureau | Show Desktop Button / `show-desktop-button@amivaleo` | version 59, review 75965 |
| CPU, mémoire, réseau | Vitals / `Vitals@CoreCoding.com` | version 85, review 74743 |
| Tuilage | Tiling Assistant / `tiling-assistant@leleat-on-github` | release GitHub v56 |

URL, version, UUID, compatibilité GNOME 51 et SHA-256 des quatre archives téléchargées sont dans `config/gnome-extensions.lock`, qui doit rester identique à `profiles/fedora45/gnome-extensions.lock`. Chaque installateur refuse une archive dont l'un de ces éléments diffère, compile les schémas et garde la provenance dans `.fedora-gnome-custom-source`.

Gtk4 DING, Show Desktop Button et Vitals remplacent Desktop Icons NG, Show Desktop Plus et Resource Monitor, qui n'ont pas de version GNOME 51. Les préfixes de configuration `DING_*`, `SHOW_DESKTOP_PLUS_*` et `RESOURCE_MONITOR_*` sont conservés comme noms de rôle. Les réglages propres aux anciennes extensions (actions de clic, badge, style d'icône de Show Desktop Plus) ne sont pas appliqués. Les sources GNOME 50 restent dans le [profil Fedora 44 historique](HISTORICAL_FEDORA44.md).

### Bureau et Corbeille (Gtk4 DING)

Le dossier XDG Desktop est `~/Bureau`, créé et enregistré par le module ; DING affiche son contenu réel. Schéma `org.gnome.shell.extensions.gtk4-ding` :

```text
show-trash             true
show-home              false
show-volumes           false
show-network-volumes   false
```

Le correctif d'arrêt de Gtk4 DING versionné dans le dépôt est vérifié en CI ; il ne vaut pas validation sur le PC réel.

### Afficher le bureau (Show Desktop Button)

Schéma `org.gnome.shell.extensions.show-desktop-button` : bouton à l'extrémité gauche du panneau (`LEFT_END`), raccourci `Super+D`. Avec DING, masquer les fenêtres révèle `~/Bureau` et la Corbeille ; un second appui restaure les fenêtres. À vérifier avec plusieurs fenêtres ouvertes sur le système installé.

### Barre système (Vitals)

| Réglage Vitals | Valeur |
|---|---|
| `update-time` | 2 secondes |
| `position-in-panel` | 2, zone droite |
| `show-processor`, `show-memory`, `show-network` | true |
| `show-temperature` | selon l'option correspondante |
| `show-gpu` | false : la mesure de charge `xe` n'est pas qualifiée |
| `hot-sensors` | `_processor_usage_`, `_memory_usage_`, `__network-rx_max__`, `__network-tx_max__` |

Les températures CPU/GPU dépendent des capteurs hwmon réellement détectés : les épingler depuis le menu Vitals. `diagnostics/resource-monitor-doctor` vérifie le capteur Ryzen (`k10temp`/`zenpower`, label `Tctl`) et la B580 `8086:e20b`. La charge GPU est **optionnelle et non mesurée** tant qu'aucun backend Intel `xe` n'est qualifié : son absence ne bloque rien et n'est jamais affichée comme un faux 0 %. CPU, RAM et réseau restent obligatoires.

### Dock et favoris

Dash to Dock : à gauche, pleine hauteur, icônes 48 px, *intellihide*, indicateurs en points, clic `focus-minimize-or-previews`, Corbeille et volumes masqués. Les favoris viennent de `GNOME_DOCK_FAVORITES` dans `config/gnome.conf`, dans cet ordre :

1. Nautilus — `org.gnome.Nautilus.desktop`
2. Brave — `brave-browser.desktop`
3. Ptyxis — `org.gnome.Ptyxis.desktop`
4. Visual Studio Code — `code.desktop`
5. Bitwarden — `com.bitwarden.desktop.desktop`
6. Slack — `com.slack.Slack.desktop`
7. LibreOffice — `libreoffice-startcenter.desktop`
8. GNOME Logiciels — `org.gnome.Software.desktop`

`scripts/gnome/configure-dock-favorites.sh` écrit `org.gnome.shell favorite-apps`, refuse un identifiant invalide ou dupliqué, puis relit l'ordre exact. Le postcheck et `diagnostics/applications-doctor` refusent aussi un lanceur `.desktop` non exporté (exports Flatpak utilisateur et système compris). Remmina reste installé mais n'est pas épinglé.

### Tuilage et apps GTK3

Tiling Assistant vient de la release GitHub officielle v56 (le projet qu'Ubuntu embarque) ; `scripts/gnome/install-tiling-assistant.sh` vérifie URL, UUID, SHA-256 et compatibilité GNOME 51. Le service utilisateur `fedora-gnome-gtk3-theme-follow.service` suit le bouton clair/sombre de GNOME et bascule les apps GTK3 entre `adw-gtk3` et `adw-gtk3-dark`.

## Soin de l'écran QD-OLED

L'écran (ROG Strix XG27AQDMES, 2560×1440 à 240 Hz) est un **QD-OLED** : une image claire et fixe affichée des heures peut laisser une trace.

| Réglage | Valeur | Effet |
|---|---|---|
| Dock *intellihide* | activé | le dock ne reste pas affiché en permanence |
| Style | sombre au premier APPLY | moins de pixels allumés ; repasser en clair dans Paramètres reste possible, le projet ne l'imposera plus |
| Assombrissement | activé | l'écran baisse d'abord en inactivité |
| Mise en veille de l'écran | 5 min | l'écran s'éteint ensuite |

Le lissage des polices reste en niveaux de gris (défaut GNOME), adapté aux sous-pixels QD-OLED. Garder activées les protections de l'écran (*Pixel Shift*, *Panel Care*). Blur My Shell reste désactivé pour limiter les variables du compositeur à 240 Hz.

## Intégration système

- **Portails** : `xdg-desktop-portal` (+ `-gnome`, `-gtk`), PipeWire et WirePlumber. `diagnostics/portal-doctor` exige ScreenCast, FileChooser, OpenURI et Notification.
- **Secrets** : GNOME Keyring, son module PAM, libsecret et Seahorse ; `org.freedesktop.secrets` doit répondre sur le bus de session.
- **Affichage** : `display-doctor` exige 2560×1440 à environ 240 Hz (`gdctl show --verbose`). La réparation conserve l'échelle 1.0, le mode SDR et le RGB complet. Un texte dégradé après veille est d'abord traité comme une régression DRM/KMS/Mutter, avant toute retouche Fontconfig.
- **Fichiers et terminal** : [Nautilus](NAUTILUS.md), [Ptyxis](PTYXIS.md) et l'[environnement Bash](HOST_BASH_UX.md). Applications : [GTK4](GTK4_APPLICATIONS.md), [AppImage](APPIMAGE.md), [codecs](MULTIMEDIA_CODECS.md).
- **Mises à jour depuis le bureau** : GNOME Logiciels ne propose plus de mises à jour parallèles ([maintenance](DESKTOP_LIFECYCLE.md)).

Une extension ne doit jamais servir à masquer un problème Mutter, Wayland ou GPU.

## Comment c'est appliqué

```text
config/gnome-polish.conf, config/gnome.conf   ← valeurs voulues
          ↓
modules/gnome/24_gnome_extensions.sh, 24b_resource_monitor.sh, 24c_ubuntu_polish.sh
   precheck  → refuse une valeur invalide
   plan      → montre ce qui va changer
   apply     → installe et écrit les réglages
   postcheck → relit chaque réglage
          ↓
./control.sh doctor polish                     ← même vérification, à tout moment
```

Pour la finition, une seule table (`gnome_polish_desired_settings`) sert à écrire, vérifier et diagnostiquer.

Sous Wayland, la première activation des extensions peut demander une nouvelle session : se déconnecter, se reconnecter, puis lancer les contrôles.

## Personnaliser

Dans `config/local.conf` (jamais versionné), puis `./install.sh --dry-run` et l'APPLY habituel :

```bash
POLISH_ACCENT_COLOR="blue"            # blue teal green yellow orange red pink purple slate
POLISH_DOCK_POSITION="BOTTOM"         # LEFT BOTTOM RIGHT
POLISH_DOCK_ICON_SIZE="40"            # 16 à 128
POLISH_START_ON_DESKTOP="false"       # revenir à la vue Activités au démarrage
POLISH_DOCK_FIXED="true"              # dock toujours visible (déconseillé sur OLED)
POLISH_IDLE_DELAY_SECONDS="600"       # veille de l'écran après 10 min
ENABLE_TILING_ASSISTANT="false"       # garder le tuilage GNOME natif
```

Le dossier du bureau (`Bureau`), l'affichage de la Corbeille et le raccourci `Super+D` sont fixés par le profil : les modifier fait échouer le precheck.

## Vérifier

```bash
./control.sh doctor polish                 # finition et soin OLED
./diagnostics/gnome-doctor                 # extensions et réglages (appelle resource-monitor-doctor)
./diagnostics/nautilus-integration-doctor  # fichiers
./diagnostics/ptyxis-doctor                # terminal
./diagnostics/portal-doctor                # portails
./diagnostics/display-doctor               # mode d'affichage
```

Chaque ligne `KO` nomme le réglage qui a dérivé et la valeur attendue.

La CI vérifie les archives, métadonnées, schémas et réglages, puis l'activation des six extensions dans une VM GNOME 51 (boot, redémarrage, restauration). Une CI verte ne promeut pas le profil et ne prouve rien sur le matériel : la Gate 3 vérifie visuellement le bureau, les températures Ryzen, la B580, l'écran et la veille sur le système installé ([preuves GNOME](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md)).

## Hors profil

- thème GNOME Shell ou Yaru imposé ;
- Blur My Shell (installable mais désactivé), Just Perfection, Dash to Panel ;
- toute extension non épinglée par URL, identité et SHA-256. Extension Manager reste un outil d'administration : une extension ajoutée à la main ne fait pas partie du profil certifié.

Ajouter une extension demande un besoin identifié, une source revue, une compatibilité GNOME 51 vérifiée et une nouvelle qualification.
