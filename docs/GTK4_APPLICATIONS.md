# Applications GTK4 / libadwaita et outils professionnels

## Objectif

Le bureau doit rester visuellement et fonctionnellement cohérent avec GNOME 50. Les applications graphiques **du bureau général** gérées automatiquement par le projet sont donc limitées à une sélection dont la pile Fedora 44 repose sur **GTK4** et **libadwaita**.

Les outils CLI, services système et outils DevOps sans interface graphique ne sont pas concernés par cette règle.

## Exception virtualisation

La virtualisation constitue une exception explicite et volontaire à la politique GTK4/libadwaita. L'objectif prioritaire de ce scope est de disposer d'un environnement KVM/QEMU/libvirt **complet, fiable et administrable graphiquement et en ligne de commande**.

Les outils suivants restent donc autorisés et gérés par le projet :

| Usage | Application | Paquet Fedora |
|---|---|---|
| Gestion complète des VM | Virtual Machine Manager | `virt-manager` |
| Console/affichage des VM | Virtual Machine Viewer | `virt-viewer` |

Leur présence ne constitue pas une violation du contrat GTK4 desktop. Cette exception est limitée au scope `KVM` / virtualisation.

## Exception applications professionnelles

Les applications professionnelles indispensables constituent une seconde exception explicite. Elles ne remplacent pas les applications GNOME natives : elles complètent la workstation pour les usages DevOps/Ops, bureautique, communication, sécurité et transfert de fichiers.

| Usage | Application | Source gérée |
|---|---|---|
| IDE / éditeur de code | Visual Studio Code | dépôt RPM signé Microsoft (`code`) |
| Navigateur | Brave | dépôt RPM signé Brave (`brave-browser`) |
| Lecteur multimédia | VLC | Fedora (`vlc`) |
| Gestionnaire de mots de passe | Bitwarden | Flathub (`com.bitwarden.desktop`) |
| Communication professionnelle | Slack | Flathub (`com.slack.Slack`) |
| Suite bureautique OOXML | ONLYOFFICE Desktop Editors | Flathub (`org.onlyoffice.desktopeditors`) |
| Suite bureautique générale | LibreOffice + langue française | Fedora (`libreoffice`, `libreoffice-langpack-fr`) |
| FTP / FTPS / SFTP | FileZilla | Fedora (`filezilla`) |
| Markdown | MarkText | Flathub (`com.github.marktext.marktext`) |
| Éditeur texte natif | GNOME Text Editor | Fedora (`gnome-text-editor`) |

La présence de ces outils ne doit jamais servir de prétexte pour ajouter arbitrairement d'autres applications non-GTK4. Toute nouvelle exception professionnelle doit être explicite, documentée et testée.

## Terminal

| Usage | Application | Paquet Fedora |
|---|---|---|
| Terminal principal | Ptyxis | `ptyxis` |

Ptyxis est le terminal de référence du projet. Il reste distinct de VS Code : l'administration système et la virtualisation doivent pouvoir être réalisées entièrement depuis le shell sans dépendre d'un IDE.

## Sélection desktop GNOME

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
| Vidéos GNOME | Showtime | `showtime` |
| Webcam/caméra | Snapshot | `snapshot` |
| Calendrier | Calendar | `gnome-calendar` |
| Horloges | Clocks | `gnome-clocks` |
| Météo | Weather | `gnome-weather` |
| Cartographie | Maps | `gnome-maps` |
| Contacts | Contacts | `gnome-contacts` |
| Numérisation | Document Scanner | `simple-scan` |

## Sources de vérité

- `manifests/packages-applications-gtk4.txt` : applications GNOME GTK4/libadwaita.
- `manifests/packages-applications-professional-fedora.txt` : applications professionnelles Fedora.
- `manifests/packages-applications-professional-vendor.txt` : RPM professionnels provenant de dépôts éditeurs signés.
- `manifests/flatpaks-applications-professional.txt` : applications professionnelles Flathub.
- `config/repos/vscode.repo` et `config/repos/brave-browser.repo` : dépôts éditeurs versionnés par le projet.

## Contrat de conformité

Le CI refuse une application ajoutée au manifeste desktop GNOME si son paquet Fedora 44 ne déclare pas GTK4/libadwaita. Les applications professionnelles suivent un contrat distinct : source explicite, paquet ou App ID exact, vérification de disponibilité et absence d'installateur non maîtrisé de type `curl | bash`.

La virtualisation suit en parallèle son propre contrat de complétude et de stabilité défini dans `VIRTUALIZATION.md`.
