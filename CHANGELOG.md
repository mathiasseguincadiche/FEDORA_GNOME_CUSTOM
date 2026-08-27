# Changelog

## 0.7.1 — 2026-08-27

- Ajout de la détection runtime `baremetal` / `wsl2` / `ci`, recalculée après la configuration locale pour empêcher un override de se faire passer pour du bare-metal.
- Ajout de `diagnostics/wsl2-doctor` avec statuts `OK`, `EXPECTED` et `KO` pour valider Fedora 44, CPU, systemd, outils, catalogue et syntaxe sans transformer les limites WSL2 en faux défauts matériels.
- `diagnostic.sh` route désormais automatiquement vers le diagnostic WSL2, CI ou workstation bare-metal.
- Le REAL APPLY est refusé immédiatement hors bare-metal, avant les autres gates.
- Les preuves et la certification de hardware baseline sont interdites hors bare-metal ; WSL2 ne peut produire aucune preuve de certification physique.
- `config/local.conf.example` conserve désormais `REAL_MACHINE_APPROVED="false"` par défaut avec instruction d'approbation explicite uniquement sur la machine native.
- Les entrypoints publics `applications-doctor`, `media-doctor` et `baseline-doctor` sont exécutables et un contrat CI vérifie les permissions/syntaxes de tous les entrypoints publics.
- Tous les workflows GitHub Actions déclarent `permissions: contents: read`.
- `actions/checkout` et `actions/upload-artifact` sont épinglées sur des SHA immuables correspondant à leurs branches majeures v4.
- Ajout de `docs/WSL2_VALIDATION.md` et mise à jour du guide/README pour formaliser la chaîne CI → WSL2 → bare-metal.

## 0.7.0 — 2026-08-25

- Passage au niveau « industrial readiness » inspiré du projet Ubuntu, sans copier son implémentation spécifique APT/Ubuntu.
- Ajout d'un workflow Architecture non-regression verrouillant GNOME/Wayland, Arc B580, réseau KVM, sécurité destructive, backup fail-closed et secrets évidents.
- Ajout d'un pretest HOST réel dans `fedora:44` installant la pile Fedora/GNOME/KVM/backup complète, avec RPM Fusion, vendor repos, Flathub et extensions GNOME 50.
- Ajout d'un vrai pretest Ubuntu Server 26.04 sous QEMU : signature Canonical + SHA-256, cloud-init, SSH, bootstrap DevOps exact du dépôt, `verify-devops`, Docker hello-world et preuve après reboot.
- Ajout d'artifacts CI : rapport, console, bootstrap et validation VM.
- Refonte complète du scope BACKUP en inventaire, repository, HOST, métadonnées KVM, VM, intégrité/rétention, restore et disaster recovery.
- Le backup pré-APPLY détecte/valide une cible externe ou distante, protège la passphrase, capture `/etc` + `/boot`, les inventaires et XML libvirt, exécute `restic check` puis un restore-canary réel.
- Le gate APPLY exige désormais que le marker backup corresponde exactement au commit Git courant.
- Ajout de `backup-now.sh`, `restore.sh`, `disaster-recovery.sh` et `backup-doctor`.
- Les sauvegardes QCOW2 exigent les VM arrêtées et utilisent `qemu-img convert`; aucune copie live n'est autorisée.
- Les restores sont staging-first et refusent les cibles système/VM actives.
- Menu opérateur étendu et documentation CI/recovery/industrial readiness ajoutée.

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
