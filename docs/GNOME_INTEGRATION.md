# GNOME / Nautilus — intégration Golden Workstation

Le bureau reste Fedora GNOME 50/Wayland proche de l'upstream. L'objectif n'est pas de copier Ubuntu/Yaru mais d'obtenir une pile GNOME maintenable, mesurable et complète pour une workstation principale.

La version applicable est celle de [`../VERSION`](../VERSION).

## Nautilus

Nautilus possède désormais un socle dédié distinct du GNOME core. Le manifeste `manifests/packages-nautilus.txt` fournit :

- Nautilus + GVfs ;
- caméra/GPhoto2 et FUSE ;
- archives via `gvfs-archive` ;
- appareils Apple/AFC via `gvfs-afc` ;
- fichiers GNOME Online Accounts via `gvfs-goa` ;
- NFS via `gvfs-nfs` ;
- aperçu rapide Sushi ;
- intégration File Roller via `file-roller-nautilus`.

SMB et MTP sont des backends optionnels déclarés séparément et activés par défaut par `NAUTILUS_ENABLE_SMB=true` et `NAUTILUS_ENABLE_MTP=true`.

La politique de previews est `local-only` afin que les volumes réseau/amovibles ne pénalisent pas inutilement le premier lancement. `NAUTILUS_ENABLE_PREVIEWS=false` converge explicitement la politique vers `never`.

`fedora-gnome-nautilus-prewarm.service` préchauffe uniquement Portal/GIO et ne démarre jamais Nautilus. `diagnostics/nautilus-coldstart-doctor` mesure donc un vrai premier démarrage Files après login.

Le contrôle fonctionnel séparé `diagnostics/nautilus-integration-doctor` certifie les backends, Sushi, File Roller, GIO, la politique de miniatures et le service prewarm. Il fait partie de la certification finale.

Voir [`NAUTILUS.md`](NAUTILUS.md) pour le contrat complet.

## Ergonomie fonctionnelle

La Golden Workstation impose les trois contrôles de fenêtre à droite :

```text
:minimize,maximize,close
```

Extensions fonctionnelles gérées :

- **Dash to Dock** — activé depuis le RPM Fedora ;
- **AppIndicator** — activé depuis le RPM Fedora pour les logiciels utilisant AppIndicator/KStatusNotifierItem ;
- **Desktop Icons NG (DING)** — installé depuis l'artefact GNOME Extensions review `74408`/version `95`, compatible GNOME Shell 50 ; `~/Bureau` est le dossier XDG Desktop, son contenu est affiché sur le fond d'écran et la Corbeille est visible ;
- **Show Desktop Plus** — installé depuis l'artefact GNOME Extensions review `70326`/version `8`, avec bouton `left-end`, clic gauche `toggle-desktop` et raccourci `Super+D` ;
- **Resource Monitor** — télémétrie CPU/RAM/réseau/B580 depuis l'artefact GNOME Extensions review piné.

Fedora 44 ne fournit pas DING dans le manifest RPM du projet. DING et Show Desktop Plus utilisent donc deux installateurs étroits qui valident les artefacts GNOME-reviewed pinés, leurs UUID, leur compatibilité GNOME 50 et leur provenance.

Extensions/outils complémentaires :

- **Blur My Shell** — désactivé dans l'état Golden afin de réduire les variables compositor à 240 Hz ;
- **Extension Manager** — installé comme outil d'administration ;
- **Just Perfection / Dash to Panel** — non imposés.

DING conserve Home, volumes externes et volumes réseau masqués par défaut. Le couple DING + Show Desktop Plus fournit une action cohérente : masquer les fenêtres révèle immédiatement le contenu réel de `~/Bureau` et la Corbeille ; le second toggle restaure les fenêtres suivies par l'extension.

Une extension ne doit jamais servir à masquer un problème Mutter/Wayland/GPU.

Voir [`GNOME_PROFILE.md`](GNOME_PROFILE.md), [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md) et [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).

## Portals et applications sandboxées

Le profil installe :

```text
xdg-desktop-portal
xdg-desktop-portal-gnome
xdg-desktop-portal-gtk
PipeWire
WirePlumber
```

`diagnostics/portal-doctor` exige notamment les surfaces D-Bus :

- ScreenCast ;
- FileChooser ;
- OpenURI ;
- Notification.

Ces portals sont utilisés par les applications Wayland/Flatpak pour le partage d'écran, les sélecteurs de fichiers, l'ouverture d'URI et les notifications.

## Secrets

GNOME Keyring, son module PAM, libsecret et Seahorse sont installés.

Sur une session GNOME, `desktop-integration-doctor` exige que :

```text
org.freedesktop.secrets
```

soit joignable via le bus utilisateur.

## Display / rendu

Les réglages de rasterisation des polices restent upstream.

`display-doctor` lit le `Current mode` de `gdctl show --verbose` et exige 2560×1440 à environ 240 Hz selon la tolérance configurée.

Le display recovery conserve :

```text
scale 1.0
SDR/default
Full RGB
```

Un problème de texte dégradé après veille est analysé d'abord comme une possible régression DRM/KMS/Mutter/link avant toute modification Fontconfig.

## Applications et terminal

Les applications graphiques natives sélectionnées utilisent GTK4/libadwaita lorsqu'une solution GNOME de qualité existe.

Ptyxis reste le terminal GNOME natif. Son intégration est contrôlée par `diagnostics/ptyxis-doctor`, tandis que `diagnostics/shell-doctor` certifie séparément la couche Bash. Toolbx/Podman ne sont pas imposés au HOST Golden : KVM reste la frontière DevOps principale.

Voir [`PTYXIS.md`](PTYXIS.md) et [`HOST_BASH_UX.md`](HOST_BASH_UX.md).

Les outils professionnels non-GTK4 restent des exceptions fonctionnelles explicites, documentées dans [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md).

## Validation

Production/bare-metal :

```bash
./diagnostics/gnome-doctor
./diagnostics/nautilus-integration-doctor
./diagnostics/nautilus-coldstart-doctor
./diagnostics/portal-doctor
./diagnostics/desktop-integration-doctor
./diagnostics/ptyxis-doctor
./diagnostics/applications-doctor
./diagnostics/display-doctor
```

GATE 2 VirtualBox :

```bash
./scripts/lab/apply-gnome-virtualbox.sh --apply
./diagnostics/virtualbox-gnome-lab-doctor
```

Le LAB VirtualBox ne remplace jamais `install.sh --apply` et n'ouvre aucun gate production. Il permet uniquement de converger et observer la surface GNOME nécessaire à la preuve visuelle DING + Show Desktop. La même ergonomie est ensuite confirmée bare-metal.

Ces contrôles sont repris dans la certification bare-metal finale selon leur scope.
