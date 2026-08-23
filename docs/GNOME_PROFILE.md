# Profil GNOME de référence

## Cible figée

Le bureau de référence du projet est **Fedora Linux 44 Workstation + GNOME 50 “Tokyo” + Wayland**.

Le projet conserve les composants Fedora/GNOME natifs et une politique applicative GTK4/libadwaita. Ptyxis reste le terminal de référence.

## Dash to Dock

**Dash to Dock est sélectionné et activé par défaut.**

- paquet : `gnome-shell-extension-dash-to-dock` ;
- source : dépôts Fedora officiels ;
- UUID : `dash-to-dock@micxgx.gmail.com` ;
- activation : gérée par `modules/gnome/24_gnome_extensions.sh` ;
- diagnostic : `diagnostics/gnome-doctor` ;
- aucune archive téléchargée manuellement depuis extensions.gnome.org ;
- aucune préférence cosmétique n'est forcée par le dépôt : position, taille, autohide, opacité et comportement restent aux valeurs Fedora/upstream tant qu'une décision explicite n'est pas prise.

Dash to Dock constitue l'unique extension GNOME Shell sélectionnée par défaut. Les autres extensions tierces restent opt-in afin de limiter les risques de régression après les mises à jour de GNOME Shell.
