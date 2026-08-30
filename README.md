# FEDORA_GNOME_CUSTOM

**Golden Workstation 0.8.0** pour Fedora Linux 44 Workstation + GNOME 50, conçue spécifiquement pour la MSI MAG B850M Mortar WiFi, Ryzen 7 7700, 48 Gio DDR5, Intel Arc B580 `xe`, deux Crucial T705 et l'écran ASUS 2560×1440/240 Hz.

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
  GNOME / Nautilus / codecs / apps / KVM
  réparation display 1440p/240 + Full RGB
        ↓
REBOOT
        ↓
CERTIFICATION FINALE
  kernel + Arc B580/xe
  cold-start Nautilus
  affichage
  5 cycles suspend/resume
```

Le projet ne promet pas artificiellement « aucun bug » : il refuse de déclarer la workstation certifiée tant que les critères mesurés ne passent pas.

## Kernel 7.2.2+

Le profil active Fedora Kernel Vanilla `@kernel-vanilla/stable`, exige au minimum Linux `7.2.2` et conserve les kernels Fedora déjà installés comme fallback. Secure Boot actif bloque cet APPLY par défaut, car les kernels Vanilla COPR nécessitent un workflow de confiance/signature explicite.

```bash
./diagnostics/kernel-doctor
scripts/kernel/rollback-to-fedora.sh
```

Aucun `force_probe`, aucun argument `xe` expérimental, aucun tweak ASPM/APST/C-State n'est appliqué à l'aveugle.

## Nautilus : vrai démarrage à froid

Le service de prewarm charge uniquement les dépendances GNOME/Portal/GIO ; **Nautilus lui-même n'est jamais pré-démarré**. Ainsi le benchmark correspond réellement au premier clic Files après login.

```bash
./diagnostics/nautilus-coldstart-doctor
```

Objectif : ≤ 1200 ms. Limite de certification : 2000 ms. Les thumbnails restent `local-only` pour éviter qu'un backend réseau ou amovible ralentisse le premier lancement.

## Affichage après veille / extinction écran

Un watcher de session observe :

- reprise après `PrepareForSleep` ;
- `MonitorsChanged` de Mutter ;
- hotplug/change DRM udev.

Il réapplique via `gdctl` la configuration certifiée : 2560×1440, ~240 Hz, scale 1.0, color mode SDR/default, plage RGB **Full**. Il ne modifie pas les options expérimentales Mutter et ne désactive pas arbitrairement le VRR.

```bash
./diagnostics/display-doctor
./repair.sh display
```

Blur My Shell est désactivé par défaut dans le profil Golden Workstation : l'effet est cosmétique et introduit une variable de compositor inutile pour une cible 240 Hz/stabilité maximale. Dash to Dock reste géré.

## Baseline pré-APPLY

Les anciennes preuves opérateur `PASS` ne suffisent plus. Les preuves RAM/NVMe doivent provenir des tests automatisés et contiennent un SHA-256 de leur log.

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

Le dépôt fournit un générateur Kickstart. Il ne sélectionne jamais un disque automatiquement et exige une confirmation destructive contenant le chemin exact du disque.

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le Kickstart généré utilise uniquement le disque explicitement sélectionné, installe Fedora Workstation et clone le dépôt. L'APPLY n'est pas lancé automatiquement : baseline, dry-run et backup restent obligatoires.

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

Chaque cycle exige kernel/GPU/display sains et un marker récent prouvant que le repair d'affichage s'est exécuté après la reprise.

## GNOME / applications / KVM / backup

Le projet conserve GNOME 50 + Wayland, SELinux Enforcing, firewalld, Nautilus/GVfs SMB-MTP-FUSE, portals, GTK4/libadwaita, Ptyxis, RPM Fusion multimédia, VS Code, Brave, VLC, Bitwarden, Slack, ONLYOFFICE, LibreOffice FR, FileZilla et MarkText.

KVM reste CLI-first via `qemu:///system`, second T705 sur `/data`, OVMF/TPM, réseau privé `devops-nat`, Ubuntu Server 26.04 et Windows 11. Restic reste fail-closed, chiffré, avec restore-canary et restauration staging-first.

## Version

`0.8.0` — Golden Workstation : kernel stable 7.2.2+, certification hardware automatisée, cold-start Nautilus mesuré, recovery affichage 1440p/240 Hz Full RGB, certification post-resume et installation Kickstart protégée.

Voir `docs/GOLDEN_WORKSTATION.md`, `docs/INSTALLATION_GUIDE.md`, `docs/HARDWARE_BASELINE_CERTIFICATION.md`, `docs/GNOME_INTEGRATION.md`, `docs/CI_VALIDATION.md` et `docs/BACKUP_RESTORE.md`.
