# Profil GNOME 50 Golden Workstation

Référence : Fedora Linux 44 Workstation + GNOME 50 + Wayland.

## Dash to Dock

Activé par défaut depuis le paquet Fedora. Les réglages upstream/Fedora sont conservés.

## Blur My Shell

Installable depuis le paquet Fedora mais **désactivé par défaut en 0.8.0**. Le profil Golden Workstation privilégie 240 Hz, latence, stabilité suspend/resume et facilité de diagnostic à un effet cosmétique de blur. Il peut être testé manuellement A/B après certification, mais ne fait pas partie de l'état certifié par défaut.

## Extension Manager

`com.mattjakeman.ExtensionManager` reste installé depuis Flathub comme interface d'administration.

## Exclusions

Just Perfection et Dash to Panel ne font pas partie du profil géré.

Toute nouvelle extension doit être compatible GNOME 50, provenir d'une source gérée, et être comparée à l'état GNOME certifié sans extension supplémentaire.
