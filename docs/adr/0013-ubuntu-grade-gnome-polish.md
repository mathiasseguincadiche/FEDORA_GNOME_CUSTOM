# ADR 0013 — Finition « Ubuntu-grade » sur GNOME upstream

**Statut : accepté**

## Contexte

Fedora livre GNOME tel que conçu par ses développeurs : cohérent mais très épuré. Ubuntu part du même GNOME et ajoute une couche de finition : dock permanent, arrivée sur le bureau, tuilage amélioré, applications anciennes harmonisées. L'objectif est de retrouver cette finition **sans** changer de distribution, sans thème de GNOME Shell et sans dépôt graphique tiers.

## Décision

Un module dédié, `gnome.polish` (`modules/gnome/24c_ubuntu_polish.sh`), piloté par `config/gnome-polish.conf`, applique :

| Élément Ubuntu | Mise en œuvre Fedora |
|---|---|
| Ubuntu Dock | Dash to Dock (RPM Fedora) : à gauche, pleine hauteur, fixe, 48 px, clic = focus/réduire/aperçus |
| Arrivée sur le bureau | `disable-overview-on-startup` |
| Enhanced Tiling | Tiling Assistant v55 (le projet qu'Ubuntu embarque), épinglé par URL GitHub + SHA-256 |
| Couleur d'accent | accent GNOME natif (`orange` par défaut) |
| Horloge / fenêtres | jour de la semaine, nouvelles fenêtres centrées |
| Applications GTK3 cohérentes | `adw-gtk3-theme` (dépôt Fedora) + service utilisateur qui suit le mode clair/sombre |

Règles :

- une seule table d'état désiré (`gnome_polish_desired_settings`) sert à APPLY, au postcheck et à `polish-doctor` : ce qui est écrit et ce qui est vérifié ne peuvent pas diverger ;
- chaque valeur est configurable et validée par le schéma de configuration (énumérations comprises) ;
- aucun thème GNOME Shell, aucun Yaru imposé, aucune extension non épinglée ;
- Blur My Shell et Just Perfection restent hors Golden (ADR inchangé).

## Conséquences

- Le bureau ressemble à Ubuntu dans son ergonomie tout en restant GNOME upstream.
- Tiling Assistant est une extension supplémentaire : une mise à jour de GNOME Shell exige de vérifier sa compatibilité, comme pour DING et Show Desktop Plus.
- Toute dérive (réglage modifié à la main, extension désactivée) est signalée par `./diagnostics/polish-doctor` et par le postcheck.
