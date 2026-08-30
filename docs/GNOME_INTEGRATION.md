# GNOME / Nautilus — intégration Golden Workstation 0.9

Le bureau reste Fedora GNOME 50/Wayland proche de l'upstream. L'objectif n'est pas de copier Ubuntu/Yaru mais d'obtenir une pile GNOME maintenable, mesurable et complète pour une workstation principale.

## Nautilus

Nautilus + GVfs SMB/MTP/caméra/FUSE et les portals GNOME sont installés. La politique de previews est `local-only` afin que les volumes réseau/amovibles ne pénalisent pas le premier lancement.

`fedora-gnome-nautilus-prewarm.service` préchauffe uniquement Portal/GIO et ne démarre jamais Nautilus. `diagnostics/nautilus-coldstart-doctor` mesure donc un vrai premier démarrage Files après login.

## Ergonomie fonctionnelle

La Golden Workstation impose les trois contrôles de fenêtre à droite :

```text
:minimize,maximize,close
```

Extensions gérées :
- **Dash to Dock** : activé depuis le RPM Fedora.
- **AppIndicator** : activé depuis le RPM Fedora pour les logiciels utilisant AppIndicator/KStatusNotifierItem.
- **Blur My Shell** : désactivé par défaut afin de réduire les variables compositor à 240 Hz.
- **Extension Manager** : installé.
- **Just Perfection / Desktop Icons** : non imposés.

Une extension ne peut pas servir à masquer un problème Mutter/Wayland/GPU.

## Portals et applications sandboxées

La 0.9.0 installe `xdg-desktop-portal`, `xdg-desktop-portal-gnome`, le fallback GTK, PipeWire et WirePlumber. `diagnostics/portal-doctor` exige les surfaces D-Bus :
- ScreenCast ;
- FileChooser ;
- OpenURI ;
- Notification.

Cela couvre les fondations utilisées par les applications Wayland/Flatpak pour le partage d'écran, les sélecteurs de fichiers, l'ouverture d'URI et les notifications.

## Secrets

GNOME Keyring, son module PAM, libsecret et Seahorse sont installés. Sur une session GNOME, `desktop-integration-doctor` exige que `org.freedesktop.secrets` soit joignable via le bus utilisateur.

## Display / rendu

Les réglages de rasterisation des polices restent upstream. `display-doctor` lit le `Current mode` de `gdctl show --verbose` et exige 2560×1440 à environ 240 Hz. Le display recovery conserve SDR/default et demande Full RGB.

## Applications

Les applications graphiques natives sélectionnées utilisent GTK4/libadwaita lorsqu'une solution GNOME de qualité existe. Les applications professionnelles non-GTK4 restent des exceptions fonctionnelles explicites.
