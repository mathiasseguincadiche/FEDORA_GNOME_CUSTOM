# FEDORA_GNOME_CUSTOM

**Golden Workstation 0.14.0** pour Fedora Linux 44 Workstation + GNOME 50, conçue pour une workstation AMD Ryzen + Intel Arc B580 avec deux NVMe Crucial T705, écran 2560×1440/240 Hz et environnement KVM/DevOps.

Le projet traite le poste de travail comme une infrastructure versionnée :

```text
mesurer → préflight → sauvegarder → converger → redémarrer → certifier
```

## Point d'entrée opérateur

Le point d'entrée recommandé au quotidien est le **Workstation Control Center** :

```bash
./control.sh
```

Il fournit une interface terminal structurée autour de neuf socles : installation, mises à jour, backup/restauration, diagnostics, kernel/boot, KVM, maintenance, certification et logs/preuves.

Le mode CLI reste disponible pour l'automatisation :

```bash
./control.sh status
./control.sh install dry-run
./control.sh update check
./control.sh update all
./control.sh backup now
./control.sh doctor all
./control.sh kernel status
./control.sh cert status
```

`./menu.sh` reste un alias de compatibilité vers le même cockpit. Les moteurs spécialisés (`install.sh`, `diagnostic.sh`, scripts backup/kernel/KVM) restent directement appelables et conservent leurs propres garde-fous.

Voir [`docs/CONTROL_CENTER.md`](docs/CONTROL_CENTER.md).

## Commencer ici

- [`docs/README.md`](docs/README.md) — portail documentaire et parcours de lecture ;
- [`docs/CONTROL_CENTER.md`](docs/CONTROL_CENTER.md) — centre de contrôle interactif et CLI ;
- [`docs/GLOSSARY.md`](docs/GLOSSARY.md) — vocabulaire Fedora/KVM/libvirt ;
- [`docs/INSTALLATION_GUIDE.md`](docs/INSTALLATION_GUIDE.md) — installation bare-metal ;
- [`docs/VIRTUALBOX_GNOME_LAB.md`](docs/VIRTUALBOX_GNOME_LAB.md) — GATE 2 GNOME/VirtualBox fail-closed ;
- [`docs/KVM_QUICKSTART.md`](docs/KVM_QUICKSTART.md) — utilisation quotidienne des VM ;
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — runbook par symptôme.

## Contrat Golden Workstation

```text
FEDORA 44 WORKSTATION
        ↓
BASELINE MATÉRIELLE
  CPU / RAM / 2× T705 / Arc B580 / EDID
        ↓
PREFLIGHT NON-MUTANT + BACKUP RESTIC
        ↓
APPLY PROTÉGÉ
  kernel-vanilla/stable latest-stable
  firmware / microcode
  GNOME 50 / Wayland / codecs / applications
  Bureau XDG + Corbeille + Show Desktop
  Resource Monitor CPU/RAM/réseau/B580
  Bash UX / portals / secrets / print-scan / VPN / power
  Arc Level Zero/OpenCL
  KVM sur /data + réseau privé fail-closed LAN/VPN
  lifecycle sécurisé + backup quotidien
        ↓
REBOOT
        ↓
CERTIFICATION BARE-METAL
  kernel réellement installé
  hardware + firmware + Arc B580/xe
  display actif 1440p/~240 Hz
  desktop/portals/lifecycle/Bash/apps/dock
  DING + Show Desktop Plus + Resource Monitor runtime
  socle KVM host
  Nautilus cold-start
  5 cycles veille/réveil physiques uniques
  matrice software known-good
```

La CI complète cette certification ; elle ne prétend pas remplacer les preuves physiques.

## 0.14.0 — Final Hardening / Release Candidate

Cette release ferme les écarts identifiés lors de la revue pré-1.0 sans ajouter de nouveau socle fonctionnel :

- runtime `unknown` fail-closed : l'absence de preuve de virtualisation n'est plus assimilée automatiquement au bare-metal ;
- contrat d'orchestration strict : `precheck`, `plan`, `apply` et `postcheck` sont obligatoires pour chaque module ;
- un échec pendant `--apply` conserve son code retour et produit toujours un rapport d'état partiellement convergé ;
- VA-API résout désormais le render node de l'Arc B580 par PCI `8086:e20b` au lieu de supposer `/dev/dri/renderD128` ;
- DING, Show Desktop Plus et Resource Monitor sont verrouillés par URL GNOME Review **et SHA-256 exact** ;
- les timers backup utilisent un runtime autonome versionné par SHA et vérifié par manifeste ;
- la rétention Restic 7 daily / 4 weekly / 6 monthly est appliquée périodiquement aux tags `full` et `daily` ;
- `sshd` est désactivé sur le HOST Fedora tandis que `openssh-clients` reste installé pour HOST → VM ;
- le guard KVM protège les LAN et les routes non-default du HOST, notamment VPN/réseaux d'entreprise, tout en préservant la route Internet par défaut ;
- les Flatpaks `community-unverified` doivent appartenir à une allowlist versionnée explicite ;
- la télémétrie Resource Monitor de la PR #32 est intégrée au contrat/documentation de release.

Choix assumés du profil : pas de chiffrement LUKS imposé par le projet, pas de Secure Boot pour le HOST Golden, kernel `kernel-vanilla/stable` le plus récent avec kernel Fedora conservé comme fallback.

## 0.13.0 — Workstation Control Center

La 0.13.0 a ajouté la couche opérateur qui manquait au projet sans déplacer la logique métier hors de ses moteurs spécialisés :

- `control.sh` devient le cockpit principal ;
- `menu.sh` reste un alias compatible ;
- interface terminal structurée et lisible avec couleurs ANSI uniquement en TTY et support `NO_COLOR=1` ;
- tableau de bord immédiat : version, Fedora, runtime, kernel, politique Golden, B580/xe, Git, backup, certification, KVM et reboot ;
- neuf sous-menus fonctionnels au lieu d'une liste plate d'actions ;
- mode CLI scriptable avec conservation des codes de retour ;
- nouveau moteur `scripts/maintenance/update-system.sh` ;
- mise à jour complète sécurisée : **backup Restic obligatoire → DNF `--refresh` → Flatpak → firmware check read-only → diagnostic → reboot status** ;
- aucun flash firmware automatique ;
- aucune logique `apply_gate_open`, Restic, nftables ou DNF dupliquée dans la couche UI ;
- le kernel Golden reste `kernel-vanilla/stable`, politique `latest-stable`, avec kernel Fedora conservé comme fallback.

## 0.12.0 — Desktop Ergonomics

La 0.12.0 a ajouté deux fonctions utilisateur au contrat Golden sans transformer GNOME en bureau lourdement thémé :

- **Desktop Icons NG (DING)** depuis l'artefact GNOME Extensions review `74408` / version de site `95`, compatible GNOME Shell 50 ;
- `~/Bureau` comme dossier XDG Desktop, avec contenu visible sur le fond d'écran ;
- **Corbeille visible**, Home/volumes externes/réseau masqués ;
- **Show Desktop Plus** depuis review `70326` / version `8` ;
- bouton Show Desktop à gauche de la barre supérieure, clic gauche toggle bureau/fenêtres ;
- `Super+D` pour le même comportement ;
- LAB GNOME VirtualBox fail-closed pour la validation graphique GATE 2.

## Matériel ciblé

Le profil versionné attend notamment :

- AMD Ryzen 7 7700 ;
- MSI MAG B850M Mortar WiFi ;
- 48 Gio DDR5 dans la baseline actuelle ;
- Intel Arc B580 PCI `8086:e20b` sur pilote `xe` ;
- deux Crucial T705 ;
- écran ASUS 2560×1440/240 Hz.

Cette précision est volontaire : un changement de composant majeur est traité comme une évolution de plateforme et doit être recertifié.

## Kernel, Arc et stabilité

Politique Golden :

```text
Golden default     kernel-vanilla/stable
Cible              latest stable upstream
Minimum actuel     7.2.2
Secure Boot HOST   désactivé par choix de profil
Fallback           kernel Fedora officiel conservé
Exclus du Golden   mainline / -rc / linux-next
```

Contrôles :

```bash
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/hardware-components-doctor
./diagnostics/graphics-doctor
./diagnostics/arc-compute-doctor
```

Aucun `force_probe`, aucun dépôt GPU tiers, aucun tweak ASPM/APST/C-State aveugle. Fedora/Mesa reste la base ; le chemin média Intel/RPM Fusion n'est convergé qu'en fonction des capacités réellement mesurées sur le render node appartenant à l'Arc B580.

## GNOME et applications

GNOME reste proche de l'upstream Adwaita/libadwaita.

Extensions fonctionnelles gérées :

- Dash to Dock ;
- AppIndicator ;
- Desktop Icons NG (DING) ;
- Show Desktop Plus ;
- Resource Monitor.

Blur My Shell et Just Perfection restent hors de l'état Golden certifié par défaut.

Resource Monitor affiche le profil Golden CPU/RAM/réseau/B580 ; sur bare-metal, l'absence d'une source de charge GPU B580 valide reste un KO plutôt qu'un faux `0 %`.

Ergonomie desktop certifiée :

```text
~/Bureau             contenu visible sur le fond d'écran
Corbeille            visible
Home/volumes         masqués
Show Desktop         bouton en haut/gauche
Clic gauche          toggle bureau/fenêtres
Super+D              toggle bureau/fenêtres
```

Dock certifié :

1. Nautilus
2. Brave
3. Ptyxis
4. Visual Studio Code
5. Bitwarden
6. Slack
7. LibreOffice
8. GNOME Software

Applications professionnelles supplémentaires : VLC, FileZilla, ONLYOFFICE, MarkText, Remmina et draw.io.

La provenance est documentée dans `manifests/application-provenance.tsv`. Les applications Flathub communautaires présentes dans le Golden sont explicitement allowlistées ; un nouvel ID `community-unverified` non approuvé bloque le precheck.

## Multimédia

Le projet assemble explicitement Fedora + RPM Fusion + FFmpeg/GStreamer + VA-API/oneVPL pour couvrir les formats courants tout en évitant les swaps graphiques aveugles.

```bash
./diagnostics/media-doctor
```

Voir [`docs/MULTIMEDIA_CODECS.md`](docs/MULTIMEDIA_CODECS.md).

## Bash host

Ptyxis ouvre Bash avec une couche légère et versionnée : `bash-completion`, `fzf`, `zoxide`, `direnv`, historique long/synchronisé, prompt Git local-only et aliases Git/Docker/Kubernetes/Terraform non destructifs.

```bash
./diagnostics/shell-doctor
```

## Affichage et veille

Le repair GNOME cible 2560×1440, ~240 Hz, scale 1.0, SDR/default et Full RGB.

```bash
./diagnostics/display-doctor
./diagnostics/nautilus-coldstart-doctor
./diagnostics/final-certification record-suspend
./diagnostics/final-certification certify
```

Une mise à jour du kernel, firmware GPU, Mesa, Mutter ou GNOME Shell peut invalider les anciennes preuves sensibles et imposer une recertification.

## KVM / VMs

KVM utilise :

```text
libvirt        qemu:///system
stockage       /data EXT4 sur le second T705
pool           devops-data
réseau         devops-nat
bridge         virbr50
CIDR           192.168.50.0/24
```

Profils invités :

- `ubuntu-devops` — Ubuntu Server 26.04, 6 vCPU, 16 Gio, 160 Gio ;
- `windows-11` — Windows 11, 4 vCPU, 12 Gio, 128 Gio, UEFI Secure Boot + TPM 2.0.

L'Arc B580 reste au HOST : aucun GPU passthrough.

### NAT custom et isolation LAN/VPN

Le NAT libvirt permet aux VM d'accéder à Internet. Une table nftables appartenant au projet bloque le forwarding entre `virbr50` et les réseaux explicitement routés par le HOST : LAN directement connecté, réseaux VPN/entreprise et tunnels non-default. La route Internet par défaut reste autorisée.

Lors d'un changement de réseau :

```text
NetworkManager event
        ↓
mode emergency
  bloque tout forwarding via virbr50
        ↓
redécouverte + validation des routes protégées
        ↓
mode normal uniquement si succès
```

Si le recalcul échoue, le mode d'urgence reste actif. Une panne de recalcul coupe donc la sortie réseau des VM au lieu de conserver une ancienne hypothèse réseau potentiellement dangereuse.

Voir [`docs/KVM_NETWORK.md`](docs/KVM_NETWORK.md).

### Ubuntu DevOps Ready

Pour créer Ubuntu, l'opérateur fournit ensemble :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

Le projet authentifie la liste de checksums avec l'empreinte Canonical attendue puis vérifie le SHA-256 de l'image avant de créer le disque.

```bash
scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

La VM est ensuite provisionnée pour `clone → build/test → containerize → deploy` : Git/GitHub/GitLab, Docker, Terraform, Ansible, AWS/Azure, kubectl/Helm/kind/Minikube/K9s, Node 22, Java 21/Maven, Python et outils Ops.

Le HOST conserve uniquement les **clients SSH** nécessaires à l'administration des VM ; le serveur `sshd` du HOST est désactivé par le Kickstart Golden.

### Windows 11

```bash
scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

Lorsque des SHA-256 obtenus depuis les sources de confiance sont disponibles, les deux ISO peuvent être vérifiées avant création.

Voir [`docs/VM_PROFILES.md`](docs/VM_PROFILES.md) et [`docs/KVM_QUICKSTART.md`](docs/KVM_QUICKSTART.md).

## Backup / recovery

Le pré-APPLY Restic est fail-closed : cible externe/remote, chiffrement du dépôt Restic, intégrité, restore test, snapshot lié au même commit et arrêt des VM pour les disques. Le profil n'impose pas de chiffrement LUKS des SSD.

La sauvegarde quotidienne résout les dossiers utilisateur via XDG afin de rester correcte quelle que soit la langue (`Bureau`, `Images`, `Vidéos`, `Musique`, etc.). Les timers exécutent un bundle autonome installé sous le SHA appliqué et vérifié par `MANIFEST.sha256`, sans dépendre du checkout Git courant.

La rétention `7 daily / 4 weekly / 6 monthly` est appliquée automatiquement chaque semaine aux snapshots `fedora-gnome-custom-full` et `fedora-gnome-custom-daily`, puis un unique `restic prune` est exécuté. Le déclenchement manuel reste disponible depuis le Control Center.

Les restores sont staging-first. La passphrase Restic doit disposer d'une copie de récupération sécurisée hors de la workstation ; elle n'est jamais sauvegardée dans le dépôt Restic lui-même.

```bash
./prepare-preapply-backup.sh
./diagnostics/backup-doctor
./diagnostics/daily-backup-doctor
scripts/backup/backup-now.sh --prune
```

Voir [`docs/BACKUP_RESTORE.md`](docs/BACKUP_RESTORE.md).

## Installation

### 1. Kickstart piné

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le générateur affiche la cible, exige `EFFACER /dev/...` et inscrit le SHA Git courant. Le `%post` fetch/checkout exactement ce SHA. Le HOST n'active pas `sshd`; `openssh-clients` reste installé pour les connexions vers les VM.

### 2. Baseline

```bash
./diagnostics/baseline-doctor snapshot
./diagnostics/baseline-doctor run-memory-test 5600
# profil mémoire BIOS à 6000 puis reboot
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

La qualification mémoire automatisée utilise **60 minutes** par profil mémoire conformément à `config/performance.conf`.

### 3. Preflight, backup, APPLY

Depuis le cockpit :

```bash
./control.sh
```

Ou directement :

```bash
./install.sh --dry-run
./prepare-preapply-backup.sh
# après revue : REAL_MACHINE_APPROVED=true dans config/local.conf
./install.sh --apply
```

Le gate exige bare-metal réellement prouvé, Git propre, preflight du même commit, baseline valide, backup Restic du même commit et confirmation exacte. Un runtime indéterminé reste `unknown` et ne peut pas ouvrir le gate.

## Mises à jour quotidiennes

Vérification read-only :

```bash
./control.sh update check
```

Mise à jour complète sécurisée :

```bash
./control.sh update all
```

La transaction complète exige bare-metal, réalise un backup Restic complet avant DNF, met ensuite à jour Fedora et les Flatpaks, consulte fwupd sans flasher, exécute le diagnostic global et indique si un reboot est requis.

## CI et gouvernance

Les workflows couvrent contrats, ShellCheck, non-régression, résolution Fedora 44, intégration host Fedora 44, vraie VM Ubuntu 26.04, sécurité KVM, cohérence documentaire, ergonomie desktop, Resource Monitor, Control Center et cloisonnement du LAB VirtualBox.

La politique cible pour `main` exige PR + checks verts et interdit force-push/suppression. Le script `scripts/development/check-main-protection.sh` reste le contrôle de conformité de ce réglage GitHub.

Voir [`docs/CI_VALIDATION.md`](docs/CI_VALIDATION.md) et [`docs/GITHUB_GOVERNANCE.md`](docs/GITHUB_GOVERNANCE.md).

## Version

`0.14.0` — **Final Hardening / Release Candidate**.

La 1.0 sera justifiée par une installation bare-metal complète, une certification finale réussie et une période d'usage réel stable — pas par l'ajout artificiel de fonctionnalités.
