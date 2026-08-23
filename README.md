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

## GNOME et applications

GNOME 50 reste la base, avec Dash to Dock, Blur My Shell et Extension Manager. Just Perfection et Dash to Panel sont exclus.

Applications professionnelles gérées : VS Code, Brave, VLC, Bitwarden, Slack, GNOME Text Editor, ONLYOFFICE Desktop Editors, LibreOffice FR, FileZilla et MarkText.

## Virtualisation

Stack : QEMU/KVM, libvirt `qemu:///system`, OVMF/UEFI, swtpm/TPM 2.0, libguestfs/libosinfo, virt-manager/virt-viewer et une surface CLI complète (`virsh`, `virt-install`, `virt-xml`, `qemu-img`, `virt-v2v`, etc.).

Le second T705 est monté **manuellement** à `/data` en EXT4. Les disques VM sont stockés dans `/data/libvirt/images`.

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

## VM de référence

### Ubuntu Server 26.04 — `ubuntu-devops`

6 vCPU, 16 Gio RAM, 160 Gio qcow2, UEFI, VirtIO, cloud-init, SSH et bootstrap DevOps complet.

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

### Windows 11 — `windows-11`

4 vCPU, 12 Gio RAM, 128 Gio qcow2, UEFI Secure Boot, TPM 2.0, VirtIO et SPICE.

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

Le script crée aussi localement un ISO `FGC_TOOLS` contenant `Configure-VMShare.ps1` pour préparer le partage Windows `C:\VM-Share` sans stocker de mot de passe.

## Accès aux fichiers des VM depuis Nautilus

Le projet ne réintroduit pas VirtioFS.

- **Ubuntu** : Nautilus accède directement au vrai `/home/mathias` de la VM par **SFTP/SSH** ; glisser-déposer, copie et ouverture de fichiers fonctionnent via GVfs.
- **Windows** : Nautilus accède à **`C:\VM-Share`** par **SMB authentifié** après exécution une fois du script PowerShell fourni sur l'ISO `FGC_TOOLS`.

Le helper découvre dynamiquement les adresses DHCP libvirt et maintient les favoris Nautilus :

```bash
bash scripts/kvm/configure_nautilus_vm_access.sh refresh
bash scripts/kvm/configure_nautilus_vm_access.sh open-ubuntu
bash scripts/kvm/configure_nautilus_vm_access.sh open-windows
```

Les favoris sont stockés dans `$XDG_CONFIG_HOME/gtk-3.0/bookmarks` (ou `~/.config/gtk-3.0/bookmarks`). Aucun identifiant ou mot de passe n'est versionné.

## Exécution HOST

```bash
./diagnostic.sh
./install.sh --dry-run
./prepare-preapply-backup.sh
./install.sh --apply
./menu.sh
```

Diagnostic KVM : `bash diagnostics/virtualization-doctor`.
Certification après création des VM : `bash scripts/kvm/runtime_certification.sh`.

## Version

`0.6.2` — intégration Nautilus des VM : SFTP/SSH pour Ubuntu et SMB authentifié pour Windows.

Documentation principale :

- `docs/CAHIER_DES_CHARGES.md`
- `docs/HARDWARE_BASELINE_CERTIFICATION.md`
- `docs/GTK4_APPLICATIONS.md`
- `docs/MULTIMEDIA_CODECS.md`
- `docs/VIRTUALIZATION.md`
- `docs/VIRTUALIZATION_CLI.md`
- `docs/VM_PROFILES.md`
- `docs/VM_FILE_ACCESS.md`
- `docs/UBUNTU_DEVOPS_PROVISIONING.md`
- `docs/EXECUTION_CONTRACT.md`
