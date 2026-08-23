# Cahier des charges V1.5 — Fedora 44 GNOME Workstation

## Finalité

Construire une workstation **Fedora 44 + GNOME 50** stable, reproductible et observable pour un usage DevOps/Ops, avec applications professionnelles, multimédia complet et virtualisation KVM/libvirt CLI-first.

## P0 — stabilité et sécurité

- Hardware Baseline Certification avant APPLY réel.
- Ryzen 7 7700, 48 Gio RAM, Intel Arc B580 `8086:e20b` sur pilote `xe`.
- Deux Crucial T705 détectés.
- DDR5 validée en SPD 5600 et XMP 6000.
- NVMe I/O soutenu et suspend/resume validés.
- Fedora 44, Wayland, SELinux Enforcing, firewalld actif.
- aucun dépôt GPU tiers ni tweak kernel expérimental par défaut.
- dry-run + backup pré-APPLY obligatoires.
- aucun partitionnement ou formatage automatique.

## P1 — bureau et applications

- GNOME 50 / GTK4 / libadwaita comme référence.
- Ptyxis comme terminal principal.
- Nautilus + GVfs SMB/MTP/FUSE.
- Dash to Dock + Blur My Shell.
- Extension Manager.
- Just Perfection et Dash to Panel exclus.
- applications professionnelles : VS Code, Brave, VLC, Bitwarden, Slack, GNOME Text Editor, ONLYOFFICE, LibreOffice FR, FileZilla et MarkText.
- les applications métier non GTK4 constituent une exception fonctionnelle explicitement documentée.

## P1 — virtualisation

### Architecture HOST

- QEMU/KVM/libvirt via `qemu:///system`.
- daemons modulaires Fedora privilégiés.
- OVMF, swtpm/TPM 2.0, VirtioFS, libguestfs, libosinfo.
- administration CLI complète ; virt-manager/virt-viewer restent complémentaires.
- Arc B580 conservée au HOST, aucun VFIO.

### Stockage

Le second T705 est dédié aux VM et monté manuellement :

```text
/data — EXT4
```

Pool `devops-data` :

```text
/data/libvirt/images
```

Arborescence gérée :

```text
/data/libvirt/{images,iso,cloud-init,nvram,snapshots,exports,shared}
```

### Réseau

```text
devops-nat
192.168.50.0/24
virbr50 = 192.168.50.254
DHCP = .100-.200
DNS = 9.9.9.9 + 1.1.1.1
```

Contrat :

```text
HOST ↔ VM          autorisé
VM ↔ VM            autorisé
VM → Internet      autorisé
VM → LAN physique  bloqué
LAN → VM           bloqué
```

La détection du LAN est dynamique. Aucun `enp*` ou `wlp*` n'est codé en dur.

### Profils invités définitifs

Seulement deux profils sont maintenus :

```text
ubuntu-devops
  Ubuntu Server 26.04
  6 vCPU / 16 Gio / 160 Gio
  UEFI / VirtIO
  cloud-init / SSH
  VirtioFS
  bootstrap DevOps complet

windows-11
  Windows 11
  4 vCPU / 12 Gio / 128 Gio
  UEFI Secure Boot
  TPM 2.0 swtpm
  VirtIO
```

Aucune VM Fedora de référence.

### Ubuntu DevOps

Utilisateur invité : `mathias`.

Le mot de passe est demandé au runtime et n'est jamais commité. L'accès SSH par clé est prioritaire.

Le bootstrap installe au minimum :

```text
Git + GitHub CLI
Docker Engine + Buildx + Compose
Ansible
Terraform
Azure CLI
AWS CLI v2
kubectl
Helm
kind
Python 3 / pip / venv / pipx
outils réseau et diagnostic
```

### Windows 11

Le profil exige deux médias opérateur :

- ISO Windows 11 ;
- `virtio-win.iso` pour les pilotes VirtIO.

Le projet ne télécharge pas ces médias automatiquement.

## P1 — certification

Host :

```bash
bash diagnostics/virtualization-doctor
```

Runtime invités :

```bash
bash scripts/kvm/runtime_certification.sh
```

Les contrôles doivent couvrir Ubuntu cloud-init/SSH/bootstrap/VirtioFS, Windows UEFI/Secure Boot/TPM/VirtIO et le contrat réseau réel.

## Ordre d'exécution

```text
BASELINE
  ↓
SYSTEM
  ↓
HARDWARE
  ↓
GNOME
  ↓
APPLICATIONS
  ↓
KVM
  ↓
BACKUP
```

Le provisioning des VM est une action opérateur **après** la convergence du HOST.

## Critère de réussite

Le dépôt est considéré prêt lorsque CI, ShellCheck, contrats de non-régression et préflight Fedora 44 sont verts. La certification hardware/runtime reste nécessaire sur la machine réelle car GitHub Actions ne possède ni le matériel ni les invités.
