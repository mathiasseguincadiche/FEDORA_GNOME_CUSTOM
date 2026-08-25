# Changelog

## 0.8.0 — 2026-08-25

- Ajout d'un contrat matériel sur mesure MSI B850M MORTAR WIFI / Ryzen 7 7700 / Arc B580 / 2× T705.
- Politique kernel Fedora-only : build officiel, taint/cmdline/microcode/AMD P-State contrôlés, aucun kernel custom automatique ni contournement global ASPM/C-state/GPU.
- Validation UEFI/Secure Boot/ReBAR, topologie PCIe et liens GPU/NVMe.
- Instrumentation systemd revue : hook de veille minimal et diagnostics lourds déplacés vers un service post-resume oneshot.
- Journald et coredump persistants/bornés, capture de santé au boot et au resume, crash forensics, pstore/kdump observables sans activation automatique dangereuse.
- Nouveaux doctors kernel/topologie/power/display/network/audio/crash/previous-boot.
- Ajout de stress-ng contrôlé pour certifier CPU/RAM et d'une procédure explicite de 10 cycles suspend/resume.
- Ajout d'un agrégateur de certification workstation et de contrats CI de non-régression matériels.

## 0.7.0 — 2026-08-25

- Passage au niveau « industrial readiness » inspiré du projet Ubuntu, sans copier son implémentation spécifique APT/Ubuntu.
- Ajout d'un workflow Architecture non-regression verrouillant GNOME/Wayland, Arc B580, réseau KVM, sécurité destructive, backup fail-closed et secrets évidents.
- Ajout d'un pretest HOST réel dans `fedora:44` installant la pile Fedora/GNOME/KVM/backup complète, avec RPM Fusion, vendor repos, Flathub et extensions GNOME 50.
- Ajout d'un vrai pretest Ubuntu Server 26.04 sous QEMU : signature Canonical + SHA-256, cloud-init, SSH, bootstrap DevOps exact du dépôt, `verify-devops`, Docker hello-world et preuve après reboot.
- Refonte complète du scope BACKUP en inventaire, repository, HOST, métadonnées KVM, VM, intégrité/rétention, restore et disaster recovery.

## 0.6.2 — 2026-08-23

- Intégration Nautilus des VM via SFTP Ubuntu et SMB Windows sans VirtioFS.

## 0.6.1 — 2026-08-23

- Suppression complète de VirtioFS/virtiofsd.

## 0.6.0 — 2026-08-23

- Deux VM de référence : Ubuntu DevOps et Windows 11.

## 0.5.0 — 2026-08-23

- Refonte KVM/QEMU/libvirt CLI-first.

## 0.4.0 — 2026-08-23

- Pile multimédia Fedora/RPM Fusion complète.

## 0.3.0 — 2026-08-22

- Scope applications GTK4/libadwaita et Ptyxis.

## 0.2.0 — 2026-08-22

- Hardware Baseline Certification avec DDR5, T705 I/O et suspend/resume.

## 0.1.0 — 2026-08-22

- Fondation Fedora 44 GNOME 50 workstation-as-code.
