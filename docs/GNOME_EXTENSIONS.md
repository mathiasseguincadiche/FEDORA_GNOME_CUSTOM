# Profil GNOME 50 premium

La référence desktop du projet est **Fedora Linux 44 Workstation + GNOME 50 Tokyo + Wayland**.

Le projet conserve GNOME proche de l'upstream et limite volontairement les extensions automatiques à celles qui apportent un bénéfice clair sans transformer le Shell en environnement difficile à diagnostiquer.

## Extensions gérées

### Dash to Dock

- activé par défaut ;
- paquet Fedora : `gnome-shell-extension-dash-to-dock` ;
- UUID : `dash-to-dock@micxgx.gmail.com` ;
- réglages Fedora/upstream conservés par défaut.

### Blur My Shell

- activé par défaut seulement après passage des gates matériels/graphiques du projet ;
- paquet Fedora : `gnome-shell-extension-blur-my-shell` ;
- UUID : `blur-my-shell@aunetx` ;
- aucun preset agressif n'est imposé : les réglages upstream/Fedora sont conservés au premier APPLY.

## Extension Manager

`com.mattjakeman.ExtensionManager` est installé depuis Flathub comme interface d'administration des extensions. Il n'est pas utilisé comme source non contrôlée pour contourner les paquets Fedora sélectionnés par le projet.

## Extension explicitement exclue

**Just Perfection n'est pas installée ni activée.** Le profil contient `ENABLE_JUST_PERFECTION="false"` et le contrat CI refuse son ajout dans les sources gérées.

## Politique

La sélection automatique est donc volontairement courte :

```text
GNOME 50 Tokyo
├── Dash to Dock
├── Blur My Shell
└── Extension Manager
```

Toute nouvelle extension doit être justifiée, compatible avec GNOME 50, testable et ne doit pas masquer une anomalie Mutter/Wayland/GPU ou compliquer la certification suspend/resume.
