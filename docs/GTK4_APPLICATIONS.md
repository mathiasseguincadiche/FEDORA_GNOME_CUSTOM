# Applications GTK4 / libadwaita et outils professionnels

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — applications et diagnostics relus contre `manifests/packages-applications-gtk4.txt`, `manifests/packages-applications-professional-fedora.txt`, `manifests/packages-applications-professional-vendor.txt` et `manifests/flatpaks-applications-professional.txt` — matériel : non vérifié

## Objectif

Le bureau doit rester visuellement et fonctionnellement cohérent avec GNOME 51. Les applications graphiques **du bureau général** gérées automatiquement par le projet sont donc limitées à une sélection dont la pile Fedora 45 repose sur GTK4/libadwaita lorsqu'une solution GNOME de qualité existe.

Les outils CLI, services système et outils DevOps sans interface graphique ne sont pas concernés par cette règle.

## Exception virtualisation

La virtualisation constitue une exception volontaire à la politique GTK4/libadwaita. L'objectif prioritaire est de disposer d'un environnement KVM/QEMU/libvirt complet, fiable et administrable graphiquement et en ligne de commande.

| Usage | Application | Paquet Fedora |
|---|---|---|
| Gestion complète des VM | Virtual Machine Manager | `virt-manager` |
| Console/affichage des VM | Virtual Machine Viewer | `virt-viewer` |

Cette exception est limitée au scope KVM/virtualisation.

## Applications professionnelles

Les applications professionnelles indispensables constituent une seconde exception explicite. Elles complètent les applications GNOME natives pour les usages DevOps/Ops, bureautique, communication, sécurité, transfert de fichiers et documentation technique.

| Usage | Application | Source gérée |
|---|---|---|
| IDE / éditeur de code | Visual Studio Code | dépôt RPM signé Microsoft (`code`) |
| Navigateur | Brave | dépôt RPM signé Brave (`brave-browser`) |
| Lecteur multimédia | VLC | Fedora (`vlc`) |
| Gestionnaire de mots de passe | Bitwarden | Flathub (`com.bitwarden.desktop`) |
| Communication professionnelle | Slack | Flathub (`com.slack.Slack`) |
| Suite bureautique | LibreOffice, langue française et intégration GTK4 | Fedora (`libreoffice`, `libreoffice-langpack-fr`, `libreoffice-gtk4`) |
| FTP / FTPS / SFTP | FileZilla | Fedora (`filezilla`) |
| Markdown | MarkText | Flathub (`com.github.marktext.marktext`) |
| Diagrammes / architecture | draw.io Desktop | Flathub (`com.jgraph.drawio.desktop`) |
| Permissions des Flatpak | Flatseal | Flathub (`com.github.tchx84.Flatseal`) |

La présence de ces outils ne doit pas servir de prétexte pour ajouter arbitrairement d'autres applications non-GTK4. Toute nouvelle exception professionnelle doit être explicite, documentée, avoir une provenance connue et être testée.

## Terminal

| Usage | Application | Paquet Fedora |
|---|---|---|
| Terminal principal | Ptyxis | `ptyxis` |

Ptyxis est le terminal de référence. L'administration système et la virtualisation doivent rester possibles depuis le shell sans dépendre de VS Code.

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

- `manifests/packages-applications-gtk4.txt` — applications GNOME GTK4/libadwaita ;
- `manifests/packages-applications-professional-fedora.txt` — applications professionnelles Fedora ;
- `manifests/packages-applications-professional-vendor.txt` — RPM provenant de dépôts éditeurs signés ;
- `manifests/flatpaks-applications-professional.txt` — applications professionnelles Flatpak ;
- `manifests/application-provenance.tsv` — classe de confiance/provenance ;
- `config/repos/vscode.repo` et `config/repos/brave-browser.repo` — dépôts éditeurs versionnés.

## Contrat de conformité

La CI refuse une application ajoutée au manifeste desktop GNOME si son paquet Fedora 45 ne respecte pas le contrat GTK4/libadwaita attendu. Les applications professionnelles suivent un contrat distinct : source explicite, paquet/App ID exact, disponibilité vérifiée et absence d'installateur non maîtrisé de type `curl | bash`.

La virtualisation suit son propre contrat de complétude et de stabilité dans [`VIRTUALIZATION.md`](VIRTUALIZATION.md).

## Vérifier les applications installées

**Pourquoi :** l'inventaire des paquets attendus ne prouve ni leur installation ni leur ouverture dans la session GNOME.

**Préparer :** sur Fedora installé après l'APPLY, ouvrir une session GNOME/Wayland, se placer à la racine du dépôt et conserver les journaux de l'installation en cas d'échec.

```bash
./diagnostics/applications-doctor
./diagnostics/application-runtime-doctor
```

- Le premier vérifie les RPM GTK4/libadwaita, les applications professionnelles activées, les Flatpak attendus et les favoris du dock. Un résultat `KO` signale une divergence à corriger.
- Le second examine la provenance et lance des vérifications de démarrage légères définies par `manifests/application-runtime-contract.tsv`. Il écrit un rapport dans `reports/` : en cas de `KO`, consulter le rapport et identifier **l'application exacte** avant toute intervention.
- **Limite :** réussir ces deux doctors ne garantit ni la fluidité de l'interface, ni les notifications, ni les sauvegardes de documents. Les essais interactifs se déroulent séparément pendant la [Gate 3](QUALIFICATION.md), avec confirmation humaine.

| Symptôme | Première vérification | Suite |
|---|---|---|
| RPM ou Flatpak absent | Comparer l'identifiant au manifeste et à la configuration des options | Revoir le journal d'installation et la provenance ; ne pas ajouter une source logicielle non approuvée. |
| Dépendance GTK4/libadwaita non reconnue | Vérifier les métadonnées RPM signalées par `applications-doctor` | Examiner le paquet exact et le contrat, sans déclarer l'application conforme sur son seul nom. |
| Favori du dock absent ou mauvais ordre | Contrôler les préférences GNOME du compte courant | Refaire le contrôle dans la session utilisateur et vérifier les lanceurs installés. |
| Contrôle de démarrage en échec | Consulter le rapport d'`application-runtime-doctor` | Isoler le paquet, l'exécutable ou le sandbox en cause ; relancer après correction vérifiée. |

Les correctifs doivent respecter les exceptions déjà décrites et la [provenance des applications](SUPPLY_CHAIN.md#applications-de-lhôte).
