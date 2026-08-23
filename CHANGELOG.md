# Changelog

## 0.6.2 — 2026-08-23

- Ajout de l'intégration Nautilus des VM sans réintroduire VirtioFS.
- Ubuntu : accès graphique au vrai `/home/mathias` via SFTP sur le SSH existant.
- Windows : partage authentifié `C:\VM-Share` via SMB, limité par Windows Firewall au réseau `192.168.50.0/24`.
- Ajout de `configure_nautilus_vm_access.sh` pour découvrir dynamiquement les leases libvirt et maintenir les favoris Nautilus.
- Ajout de `guest/windows-11/configure-smb-share.ps1` sans compte invité ni secret versionné.
- La création Windows génère et attache automatiquement un petit ISO local `FGC_TOOLS` grâce à `xorriso`.
- Ajout du module KVM `kvm.file_access`, d'options de menu et d'un contrat CI dédié.

## 0.6.1 — 2026-08-23

- Suppression complète de VirtioFS/virtiofsd et du partage HOST↔VM `/data/libvirt/shared`.
- Ubuntu conserve cloud-init, SSH et son bootstrap DevOps ; accès au filesystem invité par SSH/SFTP.

## 0.6.0 — 2026-08-23

- Contrat final limité à deux VM de référence : `ubuntu-devops` et `windows-11`; suppression du profil Fedora invité.
- `ubuntu-devops` fixé à 6 vCPU, 16 Gio RAM et 160 Gio qcow2.
- `windows-11` fixé à 4 vCPU, 12 Gio RAM et 128 Gio qcow2.
- Ajout du provisioning cloud-init/SSH/bootstrap DevOps Ubuntu et du profil Windows 11 Secure Boot/TPM/VirtIO.
- Ajout de la certification runtime on-machine.

## 0.5.0 — 2026-08-23

- Refonte complète du scope KVM/QEMU/libvirt pour Fedora 44.
- Stack CLI-first, pool `devops-data`, réseau `devops-nat`, applications professionnelles et extensions GNOME sélectionnées.

## 0.4.0 — 2026-08-23

- Pile multimédia Fedora/RPM Fusion complète.

## 0.3.0 — 2026-08-22

- Scope applications GTK4/libadwaita et Ptyxis.

## 0.2.0 — 2026-08-22

- Hardware Baseline Certification avec DDR5, T705 I/O et suspend/resume.

## 0.1.0 — 2026-08-22

- Fondation Fedora 44 GNOME 50 workstation-as-code.
