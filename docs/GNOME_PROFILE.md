# Profil GNOME de référence

## Cible

Le bureau de référence est **Fedora Linux 44 Workstation + GNOME 50 “Tokyo” + Wayland**.

Le projet conserve les composants Fedora/GNOME natifs, Adwaita/libadwaita et Ptyxis comme terminal de référence. Il ne cherche pas à reproduire Ubuntu/Yaru et évite les personnalisations qui compliquent le diagnostic du compositor.

## Extensions gérées et activées

Le profil courant active exactement les extensions fonctionnelles suivantes :

### Dash to Dock

- paquet : `gnome-shell-extension-dash-to-dock` ;
- source : dépôts Fedora officiels ;
- UUID : `dash-to-dock@micxgx.gmail.com` ;
- activation : `modules/gnome/24_gnome_extensions.sh` ;
- diagnostic : `diagnostics/gnome-doctor`.

Le projet conserve les préférences Fedora/upstream tant qu'une décision explicite n'est pas versionnée. Position, taille, autohide, opacité et animations ne sont donc pas arbitrairement forcées.

### AppIndicator

AppIndicator est également activé depuis le paquet Fedora afin de fournir la compatibilité nécessaire aux applications utilisant AppIndicator/KStatusNotifierItem.

Cette extension est **fonctionnelle**, pas cosmétique : son activation évite de perdre des indicateurs/tray attendus par certaines applications professionnelles.

## Extensions non activées dans l'état Golden

- **Blur My Shell** : désactivé afin de réduire les variables de rendu/compositor à 240 Hz et après suspend/resume ;
- **Just Perfection** : non géré ;
- **Dash to Panel** : non géré ;
- **Desktop Icons** : non imposé.

Extension Manager reste disponible comme interface d'administration, sans transformer chaque extension installable en élément du contrat Golden.

## Règle d'évolution

Toute nouvelle extension doit :

1. apporter un besoin fonctionnel clairement identifié ;
2. être compatible GNOME 50 ;
3. provenir d'une source gérée ;
4. être testée par rapport à l'état GNOME certifié ;
5. ne pas masquer une régression Mutter/Wayland/GPU.

Voir aussi [`GNOME_EXTENSIONS.md`](GNOME_EXTENSIONS.md) et [`GNOME_INTEGRATION.md`](GNOME_INTEGRATION.md).
