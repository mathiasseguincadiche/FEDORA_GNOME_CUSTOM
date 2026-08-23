# FEDORA_GNOME_CUSTOM

Workstation-as-code pour **Fedora Linux 44 Workstation + GNOME 50**, conçue pour une workstation Ryzen 7 7700 / Intel Arc B580 et un usage DevOps/Ops orienté infrastructure.

## Principes

- stabilité matérielle avant personnalisation ;
- Wayland, SELinux Enforcing et firewalld conservés ;
- Fedora officiel en priorité, RPM Fusion/Flathub/dépôts éditeurs uniquement lorsqu'ils sont explicitement justifiés ;
- aucun tweak kernel/GPU expérimental sans diagnostic ;
- aucun partitionnement/formatage automatique ;
- dry-run et backup avant APPLY ;
- virtualisation KVM/libvirt **CLI-first** ;
- aucun mot de passe ou média propriétaire stocké dans Git.

## Machine de référence

```text
CPU      AMD Ryzen 7 7700 — 8C/16T
RAM      48 Gio DDR5 — SPD 5600 / XMP 6000
GPU      Intel Arc B580 12 Gio — pilote HOST xe
SSD      2× Crucial T705 1 To
Écran    2560×1440 / 240 Hz
Desktop  Fedora 44 + GNOME 50 / Wayland
```

## GNOME

Profil :

```text
GNOME 50
├── Dash to Dock
├── Blur My Shell
└── Extension Manager
```

Just Perfection et Dash to Panel sont exclus.

## Applications professionnelles

Le projet gère notamment :

```text
VS Code
Brave
VLC
Bitwarden
Slack
GNOME Text Editor
ONLYOFFICE Desktop Editors
LibreOffice + français
FileZilla
MarkText
```

## Virtualisation

Stack :

```text
QEMU/KVM
libvirt qemu:///system
OVMF / UEFI
swtpm / TPM 2.0
VirtioFS
libguestfs
libosinfo
virt-manager / virt-viewer
virsh / virt-install / virt-xml / qemu-img / virt-v2v / etc.
```

Le second T705 est monté **manuellement** à `/data` en EXT4. Le projet crée ensuite :

```text
/data/libvirt/
├── images/
├── iso/
├── cloud-init/
├── nvram/
├── snapshots/
├── exports/
└── shared/
```

Réseau :

```text
devops-nat       192.168.50.0/24
virbr50          192.168.50.254
DHCP             .100-.200
DNS              9.9.9.9 / 1.1.1.1

HOST ↔ VM        autorisé
VM ↔ VM          autorisé
VM → Internet    autorisé
VM ↔ LAN         bloqué
```

La connectivité physique du HOST peut être Ethernet ou Wi-Fi ; aucune interface n'est codée en dur.

## Deux VM de référence

### Ubuntu Server 26.04 — `ubuntu-devops`

```text
6 vCPU
16 Gio RAM
160 Gio qcow2
UEFI
VirtIO
cloud-init
SSH
VirtioFS /data/libvirt/shared → /mnt/hostshare
```

Création :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Le mot de passe de `mathias` est demandé au runtime, hashé et jamais commité.

Le bootstrap invité installe Git/gh, Docker/Compose/Buildx, Ansible, Terraform, Azure CLI, AWS CLI v2, kubectl, Helm, kind, Python et les utilitaires d'exploitation.

### Windows 11 — `windows-11`

```text
4 vCPU
12 Gio RAM
128 Gio qcow2
UEFI Secure Boot
TPM 2.0 / swtpm
VirtIO disque/réseau
SPICE
```

Création :

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

`virtio-win.iso` contient les pilotes VirtIO Windows et doit être fourni explicitement par l'opérateur.

## Exécution HOST

```bash
./diagnostic.sh
./install.sh --dry-run
./prepare-preapply-backup.sh
./install.sh --apply
./menu.sh
```

Diagnostic KVM :

```bash
bash diagnostics/virtualization-doctor
```

Certification après création des VM :

```bash
bash scripts/kvm/runtime_certification.sh
```

## Version

`0.6.0` — profils VM définitifs, Ubuntu DevOps automatisé, Windows 11 finalisé et certification runtime.

Documentation principale :

- `docs/CAHIER_DES_CHARGES.md`
- `docs/HARDWARE_BASELINE_CERTIFICATION.md`
- `docs/GTK4_APPLICATIONS.md`
- `docs/MULTIMEDIA_CODECS.md`
- `docs/VIRTUALIZATION.md`
- `docs/VIRTUALIZATION_CLI.md`
- `docs/VM_PROFILES.md`
- `docs/UBUNTU_DEVOPS_PROVISIONING.md`
- `docs/EXECUTION_CONTRACT.md`
