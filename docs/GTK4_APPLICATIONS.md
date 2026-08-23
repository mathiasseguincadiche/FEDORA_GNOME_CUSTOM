# Applications GTK4 / libadwaita

## Objectif

Le bureau doit rester visuellement et fonctionnellement cohérent avec GNOME 50. Les applications graphiques gérées automatiquement par le projet sont donc limitées à une sélection dont la pile Fedora 44 repose sur **GTK4** et **libadwaita**.

Les outils CLI, services système, composants KVM et outils DevOps sans interface graphique ne sont pas concernés par cette règle.

## Terminal

| Usage | Application | Paquet Fedora |
|---|---|---|
| Terminal principal | Ptyxis | `ptyxis` |

Ptyxis est le terminal de référence du projet. Il est adapté aux usages DevOps grâce à ses profils et à son intégration des environnements conteneurisés.

## Sélection desktop

| Usage | Application | Paquet Fedora |
|---|---|---|
| Gestion des applications | GNOME Software | `gnome-software` |
| Réglages avancés GNOME | Tweaks | `gnome-tweaks` |
| Monitoring processus | System Monitor | `gnome-system-monitor` |
| Analyse espace disque | Disk Usage Analyzer | `baobab` |
| Calculatrice | Calculator | `gnome-calculator` |
| Éditeur texte | Text Editor | `gnome-text-editor` |
| Archives | Archive Manager | `file-roller` |
| Images | Image Viewer | `loupe` |
| PDF/documents | Papers | `papers` |
| Vidéos | Showtime | `showtime` |
| Webcam/caméra | Snapshot | `snapshot` |
| Calendrier | Calendar | `gnome-calendar` |
| Horloges | Clocks | `gnome-clocks` |
| Météo | Weather | `gnome-weather` |
| Cartographie | Maps | `gnome-maps` |
| Contacts | Contacts | `gnome-contacts` |
| Numérisation | Document Scanner | `simple-scan` |

La source de vérité technique est `manifests/packages-applications-gtk4.txt`.

## Contrat de conformité

Le CI doit refuser une application ajoutée au manifeste si son paquet Fedora 44 ne déclare pas les composants GTK4/libadwaita attendus. L'ajout d'une nouvelle application graphique passe donc par :

1. vérification du paquet Fedora 44 ;
2. vérification GTK4/libadwaita ;
3. ajout au manifeste ;
4. validation du préflight Fedora ;
5. validation du contrat applicatif.

Une application non vérifiée n'est pas installée automatiquement par le projet.
