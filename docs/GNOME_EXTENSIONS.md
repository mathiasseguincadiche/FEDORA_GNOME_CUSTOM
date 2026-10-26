# Extensions GNOME 51 — politique Golden Workstation

> Vue d’ensemble : [GNOME.md](GNOME.md). Référence : Fedora 45 Workstation + GNOME 51 + Wayland.

Le profil est sélectionné par défaut et reste `pending` jusqu’à sa [promotion](FEDORA45_PRIMARY.md). Les constantes des quatre archives téléchargées sont dans [`config/gnome-extensions.lock`](../config/gnome-extensions.lock), identique au verrou du profil Fedora 45. URL, version, UUID, compatibilité et SHA-256 sont contrôlés ensemble ; ce ne sont pas des options `local.conf`.

## Les six extensions fonctionnelles

| Rôle | Composant / identité | Source retenue |
|---|---|---|
| Dock | Dash to Dock / `dash-to-dock@micxgx.gmail.com` | RPM Fedora, version exacte dans `profiles/fedora45/gnome-rpms.json` |
| AppIndicator | `appindicatorsupport@rgcjonas.gmail.com` | RPM Fedora, même verrou |
| Icônes | Gtk4 Desktop Icons NG (DING) / `gtk4-ding@smedius.gitlab.com` | version 145, review 75162 |
| Afficher le bureau | Show Desktop Button / `show-desktop-button@amivaleo` | version 59, review 75965 |
| Télémétrie | Vitals / `Vitals@CoreCoding.com` | version 85, review 74743 |
| Tuilage | Tiling Assistant / `tiling-assistant@leleat-on-github` | release GitHub v56 |

Gtk4 DING, Show Desktop Button et Vitals remplacent les implémentations GNOME 50 Desktop Icons NG, Show Desktop Plus et Resource Monitor. Les préfixes internes `DING_*`, `SHOW_DESKTOP_PLUS_*` et `RESOURCE_MONITOR_*` gardent leur rôle pour préserver la configuration. Les anciens réglages ne sont pas transposés à une clé GSettings inexistante.

## Bureau et Corbeille

DING affiche le contenu réel du dossier XDG Desktop `~/Bureau`, créé et enregistré par le module. Le schéma `org.gnome.shell.extensions.gtk4-ding` impose :

```text
show-trash             true
show-home              false
show-volumes           false
show-network-volumes   false
```

Le téléchargement est limité à l’artefact revu. L’installateur vérifie l’UUID, GNOME 51 et l’empreinte, compile les schémas et conserve `.fedora-gnome-custom-source`. Le correctif d’arrêt Gtk4 DING versionné est également contrôlé ; il ne vaut pas validation sur le PC réel.

## Afficher le bureau

Show Desktop Button utilise `org.gnome.shell.extensions.show-desktop-button` : position `LEFT_END` et raccourci `Super+D`. Les réglages d’actions de clic, de badge ou d’icône propres à Show Desktop Plus ne sont pas appliqués à cette extension. Le comportement visible doit être vérifié avec plusieurs fenêtres en Gate 2, puis confirmé sur la workstation.

## Télémétrie

Vitals affiche CPU, RAM et débits réseau en haut à droite, toutes les deux secondes. Les températures CPU/GPU dépendent des capteurs détectés : on les épingle depuis le menu Vitals. L’affichage de la charge B580 dans la barre n’est pas garanti par Vitals.

Le doctor vérifie la présence de la B580 `8086:e20b` et signale les températures hwmon disponibles. La charge GPU est optionnelle et non mesurée tant qu’un backend `xe` n’a pas été qualifié ; son absence ne bloque pas le bureau. Les mesures CPU, RAM et réseau restent attendues. Voir [RESOURCE_MONITOR.md](RESOURCE_MONITOR.md).

## Dock, AppIndicator et tuilage

La couche `gnome.polish` configure Dash to Dock à gauche, icônes de 48 px et masquage intelligent OLED, puis Tiling Assistant pour les quarts d’écran, le remplissage et les groupes. Les réglages sont documentés dans [GNOME_POLISH.md](GNOME_POLISH.md).

Les deux RPM doivent déclarer GNOME 51 compatible. Leur présence seule ne suffit pas. Le laboratoire candidat peut utiliser les versions exactes signées depuis `updates-testing` dans sa VM ; la promotion de production exige leur disponibilité stable.

## Preuves et première session

La CI vérifie les archives, métadonnées, schémas et préférences réelles. Le laboratoire Fedora 45 personnalisé exige les **six extensions actives** après boot, reboot, restauration et reconstruction. Le laboratoire natif permet d’isoler GNOME sans extensions.

Une CI verte ne promeut pas automatiquement le profil et ne produit aucune preuve physique. La Gate 2 vérifie visuellement le bureau et ses interactions ; la Gate 3 confirme le résultat sur le matériel. Sous Wayland, ouvrir une nouvelle session si l’activation initiale des extensions le nécessite, puis exécuter `diagnostics/gnome-doctor` et `diagnostics/polish-doctor`.

## Exclusions

Blur My Shell reste installable mais désactivé dans la baseline. Just Perfection et Dash to Panel ne sont pas imposés. Extension Manager reste une interface d’administration ; une extension ajoutée manuellement ne devient pas un élément certifié du profil.

Les sources GNOME 50 sont conservées uniquement dans [le profil historique Fedora 44](HISTORICAL_FEDORA44.md).
