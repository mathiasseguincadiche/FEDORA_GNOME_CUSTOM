# FEDORA_GNOME_CUSTOM

**Golden Workstation 0.8.1** pour Fedora Linux 44 Workstation + GNOME 50, conçue spécifiquement pour la MSI MAG B850M Mortar WiFi, Ryzen 7 7700, 48 Gio DDR5, Intel Arc B580 `xe`, deux Crucial T705 et l'écran ASUS 2560×1440/240 Hz.

## Contrat 0.8

```text
INSTALLATION FEDORA 44 (Kickstart protégé)
        ↓
BASELINE PRÉ-APPLY
  RAM 5600 + 6000 automatisée
  T705 système + /data automatisés
  GPU / BIOS / NVMe / EDID fingerprint
        ↓
DRY-RUN + BACKUP RESTIC
        ↓
APPLY
  dernier kernel stable upstream (>= 7.2.2)
  microcode AMD + firmware Arc explicites
  GNOME / Nautilus / codecs / apps / KVM
  5G LAN / Wi-Fi 7 / BT / ALC4080 / xHCI
  réparation display 1440p/240 + Full RGB
        ↓
REBOOT
        ↓
CERTIFICATION FINALE
  kernel + Arc B580/xe + firmware
  carte mère / réseau / audio / USB
  cold-start Nautilus
  affichage
  5 cycles suspend/resume + xHCI
  matrice software known-good
```

Le projet ne promet pas artificiellement « aucun bug » : il refuse de déclarer la workstation certifiée tant que les critères mesurés ne passent pas.

## Kernel 7.2.2+

Le profil active Fedora Kernel Vanilla `@kernel-vanilla/stable`, exige au minimum Linux `7.2.2` et conserve les kernels Fedora déjà installés comme fallback. Secure Boot actif bloque cet APPLY par défaut, car les kernels Vanilla COPR nécessitent un workflow de confiance/signature explicite.

```bash
./diagnostics/kernel-doctor
scripts/kernel/rollback-to-fedora.sh
```

Aucun `force_probe`, aucun argument `xe` expérimental, aucun tweak ASPM/APST/C-State n'est appliqué à l'aveugle.

## Hardware completion 0.8.1

La pile installe explicitement `amd-ucode-firmware`, `intel-gpu-firmware` et certifie le Realtek 8126-VB via `r8169`, le Wi-Fi 7/6 GHz réel, Bluetooth, l'ALC4080 USB Audio/PipeWire et xHCI. Le modèle de chipset Wi-Fi n'est jamais deviné : son PCI ID/driver réels sont détectés sur la machine.

```bash
./diagnostics/firmware-doctor
./diagnostics/hardware-components-doctor
```

La certification finale enregistre également une matrice BIOS/kernel/firmware/Mesa/Mutter/GNOME/Nautilus/QEMU/libvirt. Une évolution de cette matrice invalide le statut known-good jusqu'à nouvelle certification.

## Nautilus : vrai démarrage à froid

Le service de prewarm charge uniquement les dépendances GNOME/Portal/GIO ; **Nautilus lui-même n'est jamais pré-démarré**. Ainsi le benchmark correspond réellement au premier clic Files après login.

```bash
./diagnostics/nautilus-coldstart-doctor
```

Objectif : ≤ 1200 ms. Limite de certification : 2000 ms. Les thumbnails restent `local-only` pour éviter qu'un backend réseau ou amovible ralentisse le premier lancement.

## Affichage après veille / extinction écran

Un watcher de session observe la reprise après `PrepareForSleep`, `MonitorsChanged` de Mutter et les hotplug/change DRM. Il réapplique via `gdctl` la configuration certifiée : 2560×1440, ~240 Hz, scale 1.0, SDR/default et RGB Full. Le hook sleep capture aussi réseau, audio USB et xHCI ; une erreur USB/xHCI récente invalide désormais le cycle de certification.

```bash
./diagnostics/display-doctor
./diagnostics/usb-resume-doctor
./repair.sh display
```

Blur My Shell est désactivé par défaut dans le profil Golden Workstation ; Dash to Dock reste géré.

## Baseline pré-APPLY

```bash
./diagnostics/baseline-doctor run-memory-test 5600
# changer ensuite le profil mémoire BIOS vers 6000 et redémarrer
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

Les tests NVMe travaillent sur un fichier temporaire du filesystem ; aucun benchmark destructif du block device brut n'est exécuté. `/` et `/data` doivent résoudre vers deux NVMe physiques distincts.

## Installation Fedora 44 reproductible

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le Kickstart généré utilise uniquement le disque explicitement sélectionné. L'APPLY n'est pas lancé automatiquement : baseline, dry-run et backup restent obligatoires.

## APPLY protégé

```bash
./install.sh --dry-run
./prepare-preapply-backup.sh
./install.sh --apply
```

Le gate conserve : bare-metal obligatoire, machine approuvée localement, Git propre, dry-run du même commit, baseline valide, backup Restic du même commit et confirmation exacte.

## Certification finale après reboot

Immédiatement après le premier login sur le nouveau kernel :

```bash
./diagnostics/nautilus-coldstart-doctor
```

Puis effectuer cinq cycles veille/réveil. Après chaque reprise :

```bash
./diagnostics/final-certification record-suspend
```

Enfin :

```bash
./diagnostics/final-certification certify
```

Chaque cycle exige kernel/GPU/display, carte mère et xHCI sains, plus un marker récent prouvant que le repair d'affichage s'est exécuté après la reprise.

## KVM : guest agents et profil T705 mesuré

Avant de créer Ubuntu/Windows, il est recommandé de mesurer le deuxième T705 :

```bash
./diagnostics/kvm-io-doctor benchmark
```

Le meilleur backend entre `io_uring` et AIO natif est conservé pour les nouvelles VMs. Ubuntu Server 26.04 et Windows 11 exposent QEMU Guest Agent, VirtIO RNG et balloon mémoire ; Windows expose également le channel SPICE. Le script Windows `Configure-GuestIntegration.ps1` installe les pilotes VirtIO/QEMU-GA depuis l'ISO fourni par l'opérateur.

```bash
scripts/kvm/runtime_certification.sh
```

Le runtime KVM exige notamment que les deux guest agents répondent à `guest-ping`.

## GNOME / applications / backup

Le projet conserve GNOME 50 + Wayland, SELinux Enforcing, firewalld, Nautilus/GVfs SMB-MTP-FUSE, portals, GTK4/libadwaita, Ptyxis, RPM Fusion multimédia, VS Code, Brave, VLC, Bitwarden, Slack, ONLYOFFICE, LibreOffice FR, FileZilla et MarkText. Restic reste fail-closed, chiffré, avec restore-canary et restauration staging-first.

## Version

`0.8.1` — Hardware & KVM Completion : microcode/firmware explicites, certification complète des contrôleurs de la carte mère, USB post-resume, matrice known-good, guest agents VirtIO et profil I/O T705 mesuré.

Voir `docs/GOLDEN_WORKSTATION.md`, `docs/HARDWARE_KVM_COMPLETION.md`, `docs/INSTALLATION_GUIDE.md`, `docs/HARDWARE_BASELINE_CERTIFICATION.md`, `docs/GNOME_INTEGRATION.md`, `docs/CI_VALIDATION.md` et `docs/BACKUP_RESTORE.md`.
