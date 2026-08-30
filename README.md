# FEDORA_GNOME_CUSTOM

**Golden Workstation 0.9.2** pour Fedora Linux 44 Workstation + GNOME 50, conçue spécifiquement pour la MSI MAG B850M Mortar WiFi, Ryzen 7 7700, 48 Gio DDR5, Intel Arc B580 `xe`, deux Crucial T705 et l'écran ASUS 2560×1440/240 Hz.

## Contrat Golden Workstation

```text
FEDORA 44 WORKSTATION
        ↓
BASELINE MATÉRIELLE
  RAM / CPU / T705 / Arc B580 / display
        ↓
DRY-RUN + BACKUP RESTIC
        ↓
APPLY
  kernel stable + firmware/microcode
  GNOME 50 / Wayland / codecs / apps
  dock + AppIndicator + contrôles fenêtres
  secrets + portals + print/scan + VPN + power
  Bash UX host : fzf / zoxide / direnv / completions
  Arc Level Zero/OpenCL
  KVM / deuxième T705
  lifecycle sécurisé + backup quotidien
        ↓
REBOOT
        ↓
CERTIFICATION BARE-METAL
  hardware + display actif 1440p/~240 Hz
  compute Arc + desktop/portals/lifecycle + Bash UX
  Nautilus cold-start
  5 cycles veille/réveil PHYSIQUES UNIQUES
  matrice software known-good
```

Le projet ne promet pas artificiellement « aucun bug » : il refuse de déclarer la workstation certifiée tant que les critères mesurés ne passent pas.

## Kernel et stabilité

Le profil active Fedora Kernel Vanilla `@kernel-vanilla/stable`, exige au minimum Linux `7.2.2` et conserve les kernels Fedora déjà installés comme fallback. Secure Boot actif bloque cet APPLY par défaut tant qu'un workflow de confiance/signature explicite n'est pas en place.

```bash
./diagnostics/kernel-doctor
scripts/kernel/rollback-to-fedora.sh
```

Aucun `force_probe`, aucun tweak ASPM/APST/C-State arbitraire et aucun test destructif de block device brut.

## Hardware completion

La pile gère explicitement `amd-ucode-firmware`, `intel-gpu-firmware`, Realtek 8126-VB/`r8169`/5000baseT, Wi-Fi 7/6 GHz réel, Bluetooth, ALC4080 USB Audio/PipeWire et xHCI.

```bash
./diagnostics/firmware-doctor
./diagnostics/hardware-components-doctor
./diagnostics/graphics-doctor
./diagnostics/storage-doctor
```

La matrice known-good enregistre BIOS/kernel/firmware/Mesa/Mutter/GNOME/Nautilus ainsi que les composants desktop, power, portal, Arc compute et QEMU/libvirt. Une évolution de version invalide le statut jusqu'à recertification.

## GNOME : ergonomie fonctionnelle, pas un clone d'Ubuntu

Fedora GNOME reste proche de l'upstream Adwaita/libadwaita. La 0.9.0 ajoute uniquement les fonctions quotidiennes utiles :

- Dash to Dock ;
- AppIndicator/KStatusNotifier pour les applications professionnelles ;
- boutons **Réduire / Agrandir-Restaurer / Fermer** à droite ;
- Extension Manager ;
- Blur My Shell désactivé par défaut ;
- aucune extension Desktop Icons/Just Perfection imposée.

La disposition des boutons est vérifiée via `org.gnome.desktop.wm.preferences button-layout` et doit être exactement :

```text
:minimize,maximize,close
```

## Desktop & Lifecycle Completion 0.9.0

La couche desktop certifie :

- GNOME Keyring + PAM + Secret Service ;
- xdg-desktop-portal GNOME/GTK + PipeWire/WirePlumber, avec surfaces ScreenCast/FileChooser/OpenURI/Notification ;
- CUPS + IPP-over-USB + Avahi + AirScan pour impression/scan driverless ;
- OpenVPN/OpenConnect intégrés à NetworkManager/GNOME ;
- TuneD/tuned-ppd pour les profils d'alimentation Fedora ;
- français, dictionnaires et polices Noto/Liberation ;
- Remmina RDP/VNC/SPICE ;
- libimobiledevice/ifuse ;
- Intel Arc Level Zero/OpenCL.

```bash
./diagnostics/desktop-integration-doctor
./diagnostics/portal-doctor
./diagnostics/arc-compute-doctor
./diagnostics/lifecycle-doctor
```

La politique DNF5 télécharge automatiquement les mises à jour mais **ne les installe jamais sans action de l'utilisateur** et **ne redémarre jamais automatiquement**. `fstrim.timer` reste activé ; le timer fwupd ne fait que rafraîchir les métadonnées.

## Fedora Host Bash UX 0.9.2

Ptyxis ouvre toujours Bash, mais le host dispose maintenant d'un environnement shell géré et certifié :

- `bash-completion`, `fzf`, `zoxide` et `direnv` depuis Fedora 44 ;
- historique 50 000/100 000, append, déduplication et synchronisation entre terminaux ;
- prompt Bash natif deux lignes avec chemin, branche Git, état modifié et code retour en erreur ;
- aliases Git/Docker Compose/Kubernetes/Terraform volontairement courts et non destructifs ;
- complétions `gh`, `glab`, `kubectl`, `helm`, `minikube` générées uniquement si les binaires existent, puis mises en cache ;
- aucune requête réseau depuis le prompt, aucun Starship/Oh My Bash.

Le `.bashrc` existant est sauvegardé une fois dans `~/.local/state/fedora-gnome-custom/bash/bashrc.pre-fgc`, puis seul un bloc géré source les fichiers sous `~/.config/fedora-gnome-custom/bash/`.

```bash
./diagnostics/shell-doctor
```

Voir `docs/HOST_BASH_UX.md`.

## Arc B580 : rendu + compute

La B580 reste entièrement propriétaire du host, sans passthrough. En plus de Mesa/Vulkan/VA-API, la 0.9.0 installe Intel Compute Runtime, Level Zero et OpenCL. `arc-compute-doctor` exige que `clinfo` voie réellement une plateforme et un périphérique Intel sur la machine physique.

## Nautilus

Nautilus + GVfs SMB/MTP/caméra/FUSE et les portals GNOME sont installés. Les previews sont `local-only`. Le prewarm charge Portal/GIO mais **jamais Nautilus lui-même**, afin que le benchmark mesure un vrai premier clic.

```bash
./diagnostics/nautilus-coldstart-doctor
```

Objectif : ≤ 1200 ms. Limite de certification : 2000 ms.

## Affichage et veille

Le watcher réapplique 2560×1440, ~240 Hz, scale 1.0, SDR/default et Full RGB après resume/hotplug. `display-doctor` vérifie désormais le **Current mode réellement actif**, pas simplement un mode disponible.

Chaque `record-suspend` est lié au log `latest-post.log` du hook systemd : le même cycle physique ne peut plus être compté deux fois et le marker de repair doit être postérieur à cette reprise.

```bash
./diagnostics/display-doctor
./diagnostics/usb-resume-doctor
./repair.sh display
```

## Baseline pré-APPLY

```bash
./diagnostics/baseline-doctor run-memory-test 5600
# changer ensuite le profil mémoire BIOS vers 6000 et redémarrer
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

Les tests NVMe travaillent sur des fichiers temporaires du filesystem. `/` et `/data` doivent résoudre vers deux NVMe physiques distincts.

## Installation Fedora 44

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le Kickstart utilise `@^workstation-product-environment`, le français et le fuseau America/Martinique, et n'efface que le NVMe explicitement confirmé. L'APPLY n'est jamais lancé automatiquement.

## APPLY protégé

```bash
./install.sh --dry-run
./prepare-preapply-backup.sh
./install.sh --apply
```

Le gate exige bare-metal, machine approuvée, Git propre, dry-run du même commit, baseline valide, backup Restic valide et confirmation exacte.

## Sauvegardes

Le pre-APPLY Restic reste fail-closed, chiffré, vérifié et staging-first au restore. La 0.9.0 ajoute aussi une sauvegarde quotidienne des données utilisateur via timer systemd.

Le timer quotidien :
- sauvegarde uniquement lorsque le dépôt Restic externe/remote et sa passphrase sécurisée sont disponibles ;
- n'inclut jamais le répertoire contenant la passphrase Restic ;
- ne prune jamais silencieusement ;
- enregistre son dernier succès et expose son état à `daily-backup-doctor`.

```bash
./diagnostics/backup-doctor
./diagnostics/daily-backup-doctor
```

## KVM

KVM reste CLI-first sur `qemu:///system`, avec `/data` EXT4 sur le deuxième T705, OVMF/TPM, réseau privé `devops-nat`, Ubuntu Server 26.04 et Windows 11.

```bash
./diagnostics/kvm-io-doctor benchmark
scripts/kvm/runtime_certification.sh
```

La certification runtime exige QEMU Guest Agent, VirtIO RNG/balloon, les périphériques Windows, DNS/Internet Ubuntu, la joignabilité de la gateway KVM et, lorsque la politique l'impose, la preuve que le LAN physique reste bloqué depuis la VM.

### Ubuntu DevOps Ready 0.9.1

La VM `ubuntu-devops` est maintenant conçue comme un environnement **clone → build/test → containerize → deploy** disponible dès la fin du premier bootstrap cloud-init.

Profil : 6 vCPU, 16 Gio, qcow2 160 Gio sur `/data`, Q35/UEFI, CPU host-passthrough, VirtIO, QEMU Guest Agent, RNG et balloon mémoire.

Stack installée et vérifiée :

- Git, Git LFS, GitHub CLI `gh` et GitLab CLI `glab` ;
- Docker CE, Compose v2, Buildx et containerd ;
- kubectl, Helm, kind, **Minikube avec driver Docker par défaut**, K9s, kubectx/kubens et yq Go v4 ;
- Terraform et Ansible ;
- AWS CLI v2 et Azure CLI ;
- **Node.js 22 LTS, npm et Corepack** pour Angular/JavaScript ;
- **OpenJDK 21 et Maven** pour Java/Spring ;
- Python 3/pip/venv/pipx et les utilitaires Ops usuels.

Les comptes/tokens GitHub, GitLab, AWS et Azure restent volontairement non configurés : aucune identité ni secret n'est embarqué dans la VM.

Le workflow `Ubuntu 26.04 real VM pretest` démarre une vraie image Canonical authentifiée, exécute le bootstrap exact, lance les smoke tests Docker/Node/Java/outils Kubernetes et redémarre la VM pour vérifier la persistance de la stack.

Voir `docs/UBUNTU_DEVOPS_READY.md` pour le contrat complet.

## Certification finale

Après le premier login sur le kernel cible :

```bash
./diagnostics/nautilus-coldstart-doctor
```

Effectuer ensuite **cinq vrais cycles veille/réveil** et, après chaque reprise :

```bash
./diagnostics/final-certification record-suspend
```

Puis :

```bash
./diagnostics/final-certification certify
```

La certification exige hardware/firmware/GPU/display, GNOME, desktop integration, portals, Arc compute, lifecycle, **Bash UX**, timer de backup quotidien, cold-start et cinq cycles physiques uniques.

## Version

`0.9.2` — **Fedora Host Bash UX** : Ptyxis/Bash dispose désormais d'un profil professionnel, rapide, local-only, idempotent et certifié sur l'hôte Fedora.

Voir `docs/HOST_BASH_UX.md`, `docs/UBUNTU_DEVOPS_READY.md`, `docs/DESKTOP_LIFECYCLE.md`, `docs/GNOME_INTEGRATION.md`, `docs/GOLDEN_WORKSTATION.md`, `docs/HARDWARE_KVM_COMPLETION.md`, `docs/INSTALLATION_GUIDE.md`, `docs/HARDWARE_BASELINE_CERTIFICATION.md`, `docs/CI_VALIDATION.md` et `docs/BACKUP_RESTORE.md`.
