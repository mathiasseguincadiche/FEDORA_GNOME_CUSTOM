# FEDORA_GNOME_CUSTOM

Workstation-as-code pour **Fedora Linux 44 Workstation + GNOME 50 “Tokyo”**, conçue autour de la plateforme MSI MAG B850M MORTAR WIFI, du Ryzen 7 7700, de l'Intel Arc B580 et de deux Crucial T705.

## Architecture

```text
BASELINE → SYSTEM → HARDWARE → GNOME → APPLICATIONS → KVM → BACKUP/RECOVERY
```

La couche HARDWARE est désormais sur mesure : UEFI/Secure Boot/ReBAR, topologie PCIe, kernel Fedora/microcode, AMD P-State, Arc B580/`xe`, T705, Mutter/Wayland, réseau/audio, observabilité systemd, crash forensics et certification suspend/resume.

Le projet conserve Wayland, SELinux Enforcing, firewalld et les choix Fedora upstream. Il interdit les kernels custom automatiques, `force_probe`, les contournements globaux ASPM/C-states, le governor performance permanent, le partitionnement/formatage automatique et le GPU passthrough de l'Arc B580.

## Hardware-Tailored Stability 0.8.0

Le kernel reste celui de Fedora 44. Le projet personnalise le **contrat autour du kernel** : provenance Fedora, taint, cmdline, microcode, AMD P-State, rollback, PCIe/ReBAR, runtime PM et preuves de crash. Journald/coredump sont persistants et bornés. Le hook system-sleep est minimal ; les diagnostics lourds sont exécutés après le resume par une unité systemd dédiée.

La DDR5-6000 n'est jamais considérée stable parce que la machine boote : un stress CPU/RAM et l'absence de RAS/MCE/EDAC sont requis. La veille est certifiée par 10 cycles réels avant verdict final.

```bash
diagnostics/hardware-topology-doctor
diagnostics/kernel-doctor
diagnostics/power-doctor
diagnostics/display-pipeline-doctor
diagnostics/crash-doctor
scripts/hardware/stability-stress.sh --execute --minutes 30
scripts/hardware/suspend-certify.sh --execute --cycles 10
scripts/hardware/workstation-certify.sh
```

## GNOME 50 réellement intégré

GNOME Shell, Mutter/Wayland, Nautilus/GVfs, portals, Flatpak, PipeWire/WirePlumber, Dash to Dock, Blur My Shell et Extension Manager sont gérés comme une couche desktop cohérente. Les applications natives privilégient GTK4/libadwaita ; les applications métier sont des exceptions documentées.

## KVM/libvirt CLI-first

`qemu:///system`, OVMF/UEFI, swtpm/TPM 2.0, libguestfs/libosinfo, `virsh`, `virt-admin`, `virt-install`, `virt-xml`, `qemu-img`, `virt-v2v`, etc. Le second T705 est monté **manuellement** en EXT4 sur `/data` et devient le pool `devops-data`.

Deux VM : Ubuntu Server 26.04 `ubuntu-devops` (6 vCPU, 16 Gio, 160 Gio, cloud-init/SSH/bootstrap DevOps) et Windows 11 `windows-11` (4 vCPU, 12 Gio, 128 Gio, Secure Boot, TPM 2.0, VirtIO). VirtioFS reste exclu ; Nautilus accède à Ubuntu par SFTP et à Windows par SMB authentifié.

## Validation industrielle

CI : Tests, Shell quality, Fedora 44 package preflight, Fedora 44 host integration pretest, Ubuntu 26.04 real VM pretest et Architecture non-regression. La 0.8.0 ajoute un contrat spécifique empêchant les régressions kernel/power/sleep-hook et exige les nouveaux outils de certification.

## Backup / Restore / Disaster Recovery

Restic chiffré : inventaire → repository externe/off-machine → HOST → métadonnées KVM → disques VM arrêtées → intégrité/rétention → restore staging → disaster recovery.

```bash
./diagnostic.sh
./install.sh --dry-run
./prepare-preapply-backup.sh
./install.sh --apply
./menu.sh
```

## Version

`0.8.0` — hardware-tailored stability et observabilité sur mesure pour la workstation cible.

Documentation : `docs/HARDWARE_TAILORED_STABILITY.md`, `docs/BIOS_BASELINE.md`, `docs/KERNEL_POLICY.md`, `docs/SUSPEND_CERTIFICATION.md`, `docs/CRASH_FORENSICS.md`, ainsi que les guides GNOME, KVM, CI, backup et installation existants.
