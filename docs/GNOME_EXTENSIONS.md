# Extensions GNOME 50 — politique Golden Workstation

Référence : Fedora Linux 44 Workstation + GNOME 50 + Wayland.

Le projet distingue les extensions **fonctionnelles** des extensions purement cosmétiques. L'objectif est de conserver un bureau proche de l'upstream, stable à 240 Hz et simple à diagnostiquer après une mise à jour ou un suspend/resume.

## Dash to Dock

**Activé par défaut** depuis le paquet Fedora officiel.

Le projet conserve les réglages Fedora/upstream sauf décision explicite versionnée.

## AppIndicator

**Activé par défaut** depuis le paquet Fedora officiel pour les logiciels utilisant AppIndicator/KStatusNotifierItem.

AppIndicator fait partie du contrat fonctionnel courant au même titre que Dash to Dock.

## Blur My Shell

Installable, mais **désactivé dans l'état Golden certifié**. Il ajoute un chemin de rendu cosmétique sans bénéfice fonctionnel nécessaire et complique l'analyse des régressions à 240 Hz ou après reprise de veille.

Il peut être testé manuellement A/B après certification, mais son activation ne fait pas partie de la baseline Golden.

## Extension Manager

`com.mattjakeman.ExtensionManager` reste installé depuis Flathub comme interface d'administration des extensions.

## Exclusions

Just Perfection, Dash to Panel et Desktop Icons ne sont pas imposés par le projet.

## Ajouter une extension

Une nouvelle extension doit :

- répondre à un besoin fonctionnel explicite ;
- être compatible GNOME 50 ;
- provenir d'une source gérée ;
- être testée par rapport à l'état certifié ;
- ne jamais être utilisée pour masquer un problème Mutter/Wayland/GPU.

La source de vérité détaillée du profil est [`GNOME_PROFILE.md`](GNOME_PROFILE.md).
