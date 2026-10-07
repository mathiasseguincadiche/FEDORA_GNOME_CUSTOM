# Le bureau GNOME — guide d'entrée

Ce guide est la **porte d'entrée** du pilier « finition GNOME façon Ubuntu » de la [vision du projet](VISION.md). Il ne répète pas le détail : il dit ce que fait chaque brique et vers quel document aller.

## Ce que tu obtiens

Fedora livre GNOME tel que ses développeurs l'ont conçu : propre, mais très dépouillé. Le projet garde ce GNOME officiel (GNOME 50, Wayland, Adwaita/libadwaita, applications Fedora) et lui ajoute **la finition qu'Ubuntu apporte à GNOME** :

- un dock toujours accessible et un bureau avec ses icônes ;
- un tuilage des fenêtres plus riche, des applications anciennes harmonisées avec les modernes ;
- une barre système qui montre CPU, mémoire et réseau ;
- un explorateur de fichiers et un terminal complets ;
- un soin particulier pour l'écran QD-OLED.

Ce qui n'est **pas** repris d'Ubuntu : le thème visuel Yaru et ses icônes. Le projet reprend l'ergonomie, pas l'apparence (ADR 0013).

## Les briques et leur document

| Brique | Ce qu'elle fait | Document |
| --- | --- | --- |
| Profil GNOME | Liste exacte des six extensions et de leur source | [`GNOME_PROFILE.md`](GNOME_PROFILE.md) |
| Extensions | Installation épinglée, première session, ajout d'une extension | [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md) |
| Finition façon Ubuntu | Dock, démarrage sur le bureau, tuilage, accent, GTK3, soin OLED | [`GNOME_POLISH.md`](GNOME_POLISH.md) |
| Favoris du dock | Applications épinglées et leur ordre | [`DOCK_FAVORITES.md`](DOCK_FAVORITES.md) |
| Fichiers | Nautilus complet : réseau, téléphones, archives, aperçus | [`NAUTILUS.md`](NAUTILUS.md) |
| Terminal | Ptyxis et l'environnement Bash | [`PTYXIS.md`](PTYXIS.md), [`HOST_BASH_UX.md`](HOST_BASH_UX.md) |
| Barre système | Resource Monitor : CPU, mémoire, réseau, températures | [`RESOURCE_MONITOR.md`](RESOURCE_MONITOR.md) |
| Applications | Applications GTK4/Flatpak, AppImage, codecs multimédia | [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md), [`APPIMAGE.md`](APPIMAGE.md), [`MULTIMEDIA_CODECS.md`](MULTIMEDIA_CODECS.md) |
| Intégration | Portails, trousseau de clés, affichage, applications par défaut | [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md) |
| Usage quotidien | Mises à jour, veille, sauvegarde quotidienne vues depuis le bureau | [`DESKTOP_LIFECYCLE.md`](DESKTOP_LIFECYCLE.md) |
| Matériel du bureau | Identités audio, webcam et Wi-Fi, afficheur LD240 facultatif | [`DESKTOP_COMPLETION.md`](DESKTOP_COMPLETION.md) |
| Preuves | Ce qui est vérifié en CI, en Gate 2 et en Gate 3 | [`GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md`](GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md) |

## Vérifier que tout va bien

```bash
./control.sh doctor polish                 # finition façon Ubuntu et soin OLED
./diagnostics/gnome-doctor                 # extensions et réglages GNOME
./diagnostics/nautilus-integration-doctor  # explorateur de fichiers
./diagnostics/ptyxis-doctor                # terminal
./diagnostics/resource-monitor-doctor      # barre système
./diagnostics/portal-doctor                # portails des applications
```

Chaque ligne `KO` nomme précisément ce qui ne va pas.

## Personnaliser

Tous les réglages se changent dans `config/local.conf` (jamais versionné), sans toucher au code. Les plus courants sont décrits dans [`GNOME_POLISH.md`](GNOME_POLISH.md#personnaliser) : couleur d'accent, position et taille du dock, démarrage sur le bureau, délai de mise en veille de l'écran, tuilage.

## Volontairement exclu

- le thème Yaru et ses icônes ;
- Blur My Shell, Just Perfection, Dash to Panel ;
- toute extension qui n'est pas épinglée par URL et empreinte SHA-256 dans `config/gnome-extensions.lock`.
