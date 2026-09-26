# Finition GNOME « Ubuntu-grade »

## En une phrase

Fedora livre GNOME **tel quel** ; Ubuntu ajoute une couche de finition. Ce module ajoute **la même finition** sur Fedora, sans changer de distribution ni thémer GNOME Shell. La décision est expliquée dans l'[ADR 0013](adr/0013-ubuntu-grade-gnome-polish.md).

## Ce que tu obtiens

| Avant (Fedora pur) | Après (Golden) | Pourquoi |
|---|---|---|
| Le dock n'apparaît que dans la vue Activités | Dock **toujours visible à gauche**, pleine hauteur | on lance et bascule d'une app en un clic, comme sur Ubuntu |
| La session s'ouvre sur la vue Activités | La session s'ouvre **sur le bureau** | on retrouve tout de suite ses icônes et la Corbeille |
| Clic sur une app ouverte = rien de plus | Clic = **focus**, re-clic = **réduire**, plusieurs fenêtres = **aperçus** | comportement attendu d'une barre de tâches |
| Tuilage gauche/droite seulement | **Tiling Assistant** : quarts d'écran, popup de remplissage, groupes | c'est l'« Enhanced Tiling » d'Ubuntu |
| Accent bleu | Accent **orange** (configurable) | identité visuelle proche d'Ubuntu |
| LibreOffice, FileZilla, Remmina ont un look « ancien » | Même look que les apps GNOME modernes (**adw-gtk3**), clair **et** sombre | cohérence visuelle |
| Horloge sans jour | Jour de la semaine affiché, nouvelles fenêtres centrées | petits détails de confort |

## Comment ça marche

```text
config/gnome-polish.conf          ← les valeurs voulues (une ligne = un réglage)
          ↓
modules/gnome/24c_ubuntu_polish.sh
   precheck  → refuse une valeur invalide (ex. accent « rainbow »)
   plan      → affiche ce qui va changer
   apply     → installe adw-gtk3 + Tiling Assistant, écrit les gsettings
   postcheck → relit chaque réglage et signale toute différence
          ↓
./control.sh doctor polish        ← même vérification, à tout moment
```

Point clé de qualité : **une seule table** (`gnome_polish_desired_settings`) sert à écrire les réglages, à les vérifier et au diagnostic. Impossible d'écrire une chose et d'en vérifier une autre.

### Le suivi clair / sombre des apps GTK3

Les apps GNOME modernes (libadwaita) suivent seules le mode sombre. Les apps GTK3 ne lisent qu'un nom de thème. Un petit service utilisateur, `fedora-gnome-gtk3-theme-follow.service`, écoute le bouton clair/sombre de GNOME et choisit `adw-gtk3` ou `adw-gtk3-dark` automatiquement.

### Tiling Assistant épinglé

L'extension vient de la release GitHub officielle v55 (le projet qu'Ubuntu embarque). Le script `scripts/gnome/install-tiling-assistant.sh` refuse l'installation si l'URL, l'UUID, le SHA-256 ou la compatibilité GNOME 50 ne correspondent pas exactement.

## Personnaliser

Tout se règle dans `config/local.conf` (jamais versionné), par exemple :

```bash
POLISH_ACCENT_COLOR="blue"            # blue teal green yellow orange red pink purple slate
POLISH_DOCK_POSITION="BOTTOM"         # LEFT BOTTOM RIGHT
POLISH_DOCK_ICON_SIZE="40"            # 16 à 128
POLISH_START_ON_DESKTOP="false"       # revenir à la vue Activités au démarrage
ENABLE_TILING_ASSISTANT="false"       # garder le tuilage GNOME natif
```

Puis `./install.sh --dry-run` pour voir le plan, et l'APPLY habituel.

## Vérifier

```bash
./control.sh doctor polish
```

Chaque ligne `KO` indique le réglage exact qui a dérivé et la valeur attendue.

## Ce qui reste volontairement hors du profil

- thème GNOME Shell ou Yaru imposé ;
- Blur My Shell, Just Perfection, Dash to Panel ;
- toute extension non épinglée par URL + SHA-256.
