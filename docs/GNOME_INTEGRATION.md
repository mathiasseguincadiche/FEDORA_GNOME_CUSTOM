# GNOME / Nautilus — intégration Golden Workstation

Le bureau reste Fedora GNOME 50/Wayland proche de l'upstream. L'objectif n'est pas de copier Ubuntu/Yaru mais d'obtenir une pile GNOME maintenable, mesurable et complète pour une workstation principale.

La version applicable est celle de [`../VERSION`](../VERSION).

## Nautilus

Nautilus + GVfs SMB/MTP/caméra/FUSE et les portals GNOME sont installés.

La politique de previews est `local-only` afin que les volumes réseau/amovibles ne pénalisent pas inutilement le premier lancement.

`fedora-gnome-nautilus-prewarm.service` préchauffe uniquement Portal/GIO et ne démarre jamais Nautilus. `diagnostics/nautilus-coldstart-doctor` mesure donc un vrai premier démarrage Files après login.

## Ergonomie fonctionnelle

La Golden Workstation impose les trois contrôles de fenêtre à droite :

```text
:minimize,maximize,close
```

Extensions gérées :

- **Dash to Dock** — activé depuis le RPM Fedora ;
- **AppIndicator** — activé depuis le RPM Fedora pour les logiciels utilisant AppIndicator/KStatusNotifierItem ;
- **Blur My Shell** — désactivé dans l'état Golden afin de réduire les variables compositor à 240 Hz ;
- **Extension Manager** — installé comme outil d'administration ;
- **Just Perfection / Desktop Icons** — non imposés.

Une extension ne doit jamais servir à masquer un problème Mutter/Wayland/GPU.

Voir [`GNOME_PROFILE.md`](GNOME_PROFILE.md) et [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md).

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

## Applications

Les applications graphiques natives sélectionnées utilisent GTK4/libadwaita lorsqu'une solution GNOME de qualité existe.

Les outils professionnels non-GTK4 restent des exceptions fonctionnelles explicites, documentées dans [`GTK4_APPLICATIONS.md`](GTK4_APPLICATIONS.md).

## Validation

```bash
./diagnostics/gnome-doctor
./diagnostics/portal-doctor
./diagnostics/desktop-integration-doctor
./diagnostics/applications-doctor
./diagnostics/display-doctor
```

Ces contrôles sont repris dans la certification bare-metal finale selon leur scope.
