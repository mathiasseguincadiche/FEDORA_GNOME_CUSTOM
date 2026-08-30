# Desktop & Lifecycle Completion — 0.9.0

## But

Compléter Fedora 44 Workstation/GNOME 50 pour une utilisation quotidienne et professionnelle sans transformer le système en clone d'Ubuntu ni multiplier les tweaks.

## Capacités certifiées

`diagnostics/desktop-integration-doctor` vérifie la présence et l'intégration de :
- GNOME Keyring / PAM / Secret Service ;
- CUPS, IPP-over-USB, Avahi et AirScan ;
- OpenVPN/OpenConnect pour NetworkManager ;
- TuneD + tuned-ppd ;
- français, Hunspell/Hyphen/Mythes, Noto et Liberation ;
- Remmina et ses plugins RDP/VNC/secret/SPICE ;
- libimobiledevice/ifuse.

Aucune imprimante, aucun scanner et aucun VPN actif n'est requis : la certification porte sur la capacité du système, pas sur la présence d'un périphérique externe.

## Portals Wayland

`diagnostics/portal-doctor` vérifie les paquets et services xdg-desktop-portal/PipeWire/WirePlumber et introspecte `org.freedesktop.portal.Desktop`.

Les interfaces ScreenCast, FileChooser, OpenURI et Notification doivent être exposées dans la session GNOME.

## Intel Arc compute

`diagnostics/arc-compute-doctor` exige :
- PCI `8086:e20b` ;
- Intel Compute Runtime ;
- Level Zero ;
- OpenCL ;
- une plateforme et un périphérique Intel réellement visibles dans `clinfo`.

Le GPU reste host-owned et aucun passthrough n'est activé.

## Lifecycle

Le fichier `/etc/dnf/automatic.conf` est convergé avec la politique suivante :
- téléchargement automatique : oui ;
- installation automatique : non ;
- reboot automatique : jamais.

`dnf5-automatic.timer`, `fstrim.timer` et, lorsqu'il existe, `fwupd-refresh.timer` sont activés. Le timer fwupd ne flashe aucun firmware : il rafraîchit les métadonnées.

## Sauvegarde quotidienne

`fedora-gnome-daily-backup.timer` lance une sauvegarde Restic des données utilisateur lorsque le repository et sa passphrase sécurisée sont accessibles.

Principes :
- chiffrement Restic obligatoire ;
- passphrase Restic exclue des sources ;
- pas de prune automatique ;
- absence du disque externe = skip propre ;
- le backup pré-APPLY reste indépendant et fail-closed.

## Veille / affichage

Chaque preuve suspend contient un `cycle_id` dérivé du log physique post-resume. Un même log ne peut être enregistré qu'une fois. Le marker de réparation display doit avoir une date supérieure ou égale au log de reprise.

`display-doctor` valide uniquement le mode marqué `Current mode`.

## KVM

La certification runtime conserve QGA/RNG/balloon et rétablit la preuve du garde réseau :
- table nft de protection présente ;
- gateway privée KVM joignable depuis Ubuntu ;
- gateway du LAN physique non joignable depuis Ubuntu lorsque `KVM_BLOCK_PHYSICAL_LAN=true`.

## Limites honnêtes

Une CI ne peut pas simuler l'intégralité du matériel physique. La 0.9.0 est donc fusionnable uniquement après CI verte, puis doit encore passer la certification bare-metal sur la workstation réelle.
