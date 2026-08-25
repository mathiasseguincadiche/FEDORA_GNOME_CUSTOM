# FEDORA_GNOME_CUSTOM

Workstation-as-code pour **Fedora Linux 44 Workstation + GNOME 50 “Tokyo”**, conçue autour d'un Ryzen 7 7700, d'une Intel Arc B580 et d'un usage DevOps/Ops infrastructure.

## Architecture

```text
BASELINE → SYSTEM → HARDWARE → GNOME → APPLICATIONS → KVM → BACKUP/RECOVERY
```

Le projet conserve Wayland, SELinux Enforcing, firewalld et les choix Fedora upstream. Il interdit les tweaks kernel/GPU expérimentaux sans diagnostic, le partitionnement/formatage automatique, le GPU passthrough de l'Arc B580 et les mutations globales de firewall.

## GNOME 50 réellement intégré

Le scope GNOME gère GNOME Shell, Mutter/Wayland, Nautilus/GVfs, portals, Flatpak, PipeWire/WirePlumber, Dash to Dock, Blur My Shell et Extension Manager. Les applications natives sont GTK4/libadwaita lorsqu'une solution GNOME de qualité existe ; les applications métier constituent des exceptions documentées.

Applications professionnelles gérées : VS Code, Brave, VLC, Bitwarden, Slack, GNOME Text Editor, ONLYOFFICE, LibreOffice FR, FileZilla et MarkText.

## KVM/libvirt CLI-first

`qemu:///system`, OVMF/UEFI, swtpm/TPM 2.0, libguestfs/libosinfo, `virsh`, `virt-admin`, `virt-install`, `virt-xml`, `qemu-img`, `virt-v2v`, etc.

Stockage VM : second T705 monté **manuellement** en EXT4 sur `/data`, pool `devops-data` dans `/data/libvirt/images`.

Réseau : `devops-nat` / `virbr50` / `192.168.50.0/24`, gateway `192.168.50.254`, DHCP `.100-.200`, DNS `9.9.9.9` + `1.1.1.1`. HOST↔VM, VM↔VM et VM→Internet sont autorisés ; VM↔LAN physique et forwarding entrant restent bloqués.

## Deux VM de référence

**Ubuntu Server 26.04 `ubuntu-devops`** : 6 vCPU, 16 Gio, 160 Gio qcow2, UEFI, VirtIO, cloud-init, SSH et bootstrap Git/gh, Docker, Ansible, Terraform, Azure CLI, AWS CLI, kubectl, Helm, kind et outils complémentaires.

**Windows 11 `windows-11`** : 4 vCPU, 12 Gio, 128 Gio qcow2, UEFI Secure Boot, TPM 2.0/swtpm, VirtIO et SPICE.

VirtioFS reste exclu. Nautilus accède au vrai `/home/mathias` Ubuntu via SFTP/SSH et à `C:\VM-Share` via SMB authentifié côté Windows.

## Validation industrielle

La CI comprend désormais cinq niveaux complémentaires :

1. **Tests** — contrats statiques/structure/non-régression fonctionnelle ;
2. **Shell quality** — syntaxe Bash + ShellCheck ;
3. **Fedora 44 package preflight** — résolution des sources et contrats packages ;
4. **Fedora 44 host integration pretest** — installation réelle de la pile Fedora/GNOME/KVM dans `fedora:44` ;
5. **Ubuntu 26.04 real VM pretest** — image Canonical signée + SHA-256, vraie VM QEMU (KVM si disponible), cloud-init, bootstrap DevOps réel, Docker smoke test et reboot persistence.

Un workflow **Architecture non-regression** verrouille en plus Wayland, GNOME, GPU, réseau KVM, sécurité destructive, backup fail-closed et absence de secrets évidents.

## Backup / Restore / Disaster Recovery

Restic chiffré est maintenant structuré en pipeline : inventaire → repository → HOST → métadonnées KVM → disques VM → intégrité/rétention → restore staging → disaster recovery.

Le pré-APPLY exige un repository externe/off-machine, une passphrase hors Git, `restic check`, un restore-canary réel et un marker lié au **même commit Git** que l'APPLY. Les QCOW2 ne sont sauvegardés qu'avec VM arrêtée ; les restores sont staging-first et n'écrasent jamais automatiquement le système live.

```bash
./diagnostic.sh
./install.sh --dry-run
./prepare-preapply-backup.sh
./install.sh --apply
./menu.sh
```

Outils recovery :

```bash
diagnostics/backup-doctor
scripts/backup/backup-now.sh
scripts/backup/backup-now.sh --include-vms
scripts/backup/restore.sh list
scripts/backup/disaster-recovery.sh
```

## Version

`0.7.0` — industrial readiness : CI non-régression, pretest HOST Fedora 44, vraie VM Ubuntu 26.04 avec bootstrap/reboot, et chaîne backup/restore/DR fail-closed.

Documentation principale : `docs/INSTALLATION_GUIDE.md`, `docs/INDUSTRIAL_READINESS.md`, `docs/CI_VALIDATION.md`, `docs/BACKUP_RESTORE.md`, `docs/HARDWARE_BASELINE_CERTIFICATION.md`, `docs/GNOME_INTEGRATION.md`, `docs/VIRTUALIZATION.md`, `docs/VIRTUALIZATION_CLI.md`, `docs/VM_PROFILES.md`, `docs/VM_FILE_ACCESS.md`, `docs/UBUNTU_DEVOPS_PROVISIONING.md` et `docs/EXECUTION_CONTRACT.md`.
