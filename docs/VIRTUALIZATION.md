# Virtualisation — Fedora 44 / KVM / libvirt

## Rôle du document

Ce document décrit l'architecture KVM normative de la workstation. Pour l'utilisation quotidienne, commencer par [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md). Pour le dépannage, utiliser [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md).

La source exécutable des valeurs reste :

- [`../config/virtualization.conf`](../config/virtualization.conf) ;
- [`../config/vm-profiles.conf`](../config/vm-profiles.conf).

Une contradiction entre ces fichiers, les scripts et ce document est un bug.

## Architecture de référence

```text
Fedora 44 HOST
│
├── KVM / QEMU / libvirt : qemu:///system
│   ├── domaine ubuntu-devops
│   ├── domaine windows-11
│   ├── pool devops-data → /data/libvirt/images
│   └── réseau devops-nat → virbr50 → 192.168.50.0/24
│
├── T705 #2 /data EXT4 persistant
│   ├── Documents/
│   ├── Projets/
│   ├── ISO/
│   ├── Jeux/
│   └── libvirt/
│       ├── images/
│       ├── iso/
│       ├── cloud-init/
│       ├── nvram/
│       ├── snapshots/
│       └── exports/
│
└── Intel Arc B580
    └── reste exclusivement attachée au HOST avec xe
```

## KVM, QEMU et libvirt

Sur le bare-metal :

```text
AMD-V/SVM → obligatoire
/dev/kvm  → obligatoire
kvm_amd   → obligatoire
```

La connexion de référence est `qemu:///system`. Le projet privilégie les daemons modulaires Fedora (`virtqemud`, `virtnetworkd`, `virtstoraged`, `virtlogd`, `virtlockd`) avec fallback `libvirtd` seulement lorsque nécessaire.

`virt-manager` et `virt-viewer` restent disponibles, mais aucune opération essentielle ne dépend de la GUI.

## GPU

```text
Fedora HOST → Intel Arc B580 / xe
VM          → périphérique vidéo virtuel
```

Aucun VFIO/passthrough automatique n'est autorisé. Le contrat graphique HOST 2560×1440/~240 Hz reste prioritaire.

Windows utilise `SPICE + virtio video` pour sa console. Ce n'est pas l'équivalent d'un GPU physique attribué au guest.

## Second T705 et séparation SELinux

`/data` est un montage EXT4 préparé par l'opérateur. Le projet ne partitionne et ne formate jamais automatiquement le second T705.

Les racines utilisateur :

```text
/data/Documents
/data/Projets
/data/ISO
/data/Jeux
```

sont privées (`0750`), appartiennent à l'utilisateur workstation et suivent la politique SELinux `user_home_t`.

Le sous-arbre `/data/libvirt` est séparé et conserve le contexte libvirt `virt_image_t`.

`/data/ISO` est une bibliothèque utilisateur. Les médias explicitement consommés par libvirt sont préparés dans `/data/libvirt/iso` ; le projet n'expose pas automatiquement toute la bibliothèque utilisateur à QEMU.

Avant les VM :

```bash
./control.sh doctor data
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Le benchmark ne touche pas au block device brut. Les nouvelles VM utilisent le profil I/O retenu avec `cache=none` et `discard=unmap`; `detect_zeroes` et IOThread ne sont ajoutés que si `virt-install` les supporte.

## Pool libvirt

```text
nom       devops-data
type      dir
cible     /data/libvirt/images
autostart oui
```

## Réseau privé fail-closed

```text
nom       devops-nat
bridge    virbr50
réseau    192.168.50.0/24
gateway   192.168.50.254
DHCP      192.168.50.100-200
DNS       9.9.9.9 + 1.1.1.1
mode      NAT IPv4
zone      firewalld libvirt
```

Contrat :

```text
HOST ↔ VM          autorisé
VM ↔ VM            autorisé
VM → Internet      autorisé
VM → LAN uplink    bloqué
LAN uplink → VM    bloqué en forwarding
Internet → VM      aucun forwarding implicite
```

Le guard redécouvre l'uplink IPv4. Lors d'un changement réseau, il passe d'abord en **mode d'urgence**, bloque le forwarding via `virbr50`, puis reconstruit les règles normales. Si le reconcile échoue, l'état restrictif reste actif.

Voir [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Profil `ubuntu-devops`

```text
OS                 Ubuntu Server 26.04 LTS
vCPU               6
RAM                16 Gio
disque             160 Gio qcow2
machine            Q35
CPU                host-passthrough
firmware           UEFI
disque/réseau      VirtIO
cloud-init         oui
QEMU Guest Agent   oui
VirtIO RNG         oui
balloon            oui
SSH                clé publique uniquement
autostart          non
```

L'opérateur fournit ensemble :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

`create_ubuntu_devops_vm.sh` authentifie `SHA256SUMS` avec la clé Canonical attendue, puis vérifie le SHA-256 de l'image **avant** toute création de disque.

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Le mot de passe demandé est réservé à la console et à `sudo`; SSH reste key-only.

Voir [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md) et [`UBUNTU_DEVOPS_PROVISIONING.md`](UBUNTU_DEVOPS_PROVISIONING.md).

## Profil `windows-11`

```text
OS                 Windows 11
vCPU               4
RAM                12 Gio
disque             128 Gio qcow2
machine            Q35
CPU                host-passthrough
firmware           UEFI Secure Boot
TPM                2.0 / swtpm
disque/réseau      VirtIO
QEMU Guest Agent   oui
VirtIO RNG         oui
balloon            oui
graphique          SPICE + virtio video
autostart          non
```

Windows et VirtIO sont fournis par l'opérateur depuis leurs sources de confiance. **Les deux SHA-256 de confiance sont obligatoires** : le script refuse de créer le disque si l'un manque.

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso \
  --windows-sha256 '<sha256-windows-de-confiance>' \
  --virtio-sha256 '<sha256-virtio-de-confiance>'
```

Les hashes sont vérifiés avant `qemu-img create`. Le script génère aussi `windows-guest-tools.iso` avec `Configure-GuestIntegration.ps1` et `Configure-VMShare.ps1`.

## Accès fichiers

```text
Fedora / Nautilus
├── SFTP/SSH → ubuntu-devops → /home/mathias
└── SMB      → windows-11   → C:\VM-Share
```

Aucun partage HOST VirtioFS automatique n'appartient au profil Golden.

Voir [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md).

## Validation

Avant création :

```bash
./control.sh doctor data
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Après installation des deux VM :

```bash
bash scripts/kvm/runtime_certification.sh
```

La certification vérifie notamment domaines, QEMU Guest Agent, VirtIO RNG/balloon, Secure Boot+TPM Windows, réseau/disque VirtIO, guard KVM, IP guests, SSH Ubuntu, stack DevOps, DNS/HTTPS et isolement LAN.

Une preuve live complète `LAN → VM` nécessite un deuxième appareil du LAN ; la procédure est documentée dans [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Backup des VM

```text
VM arrêtée
   ↓
qemu-img check
   ↓
qemu-img convert vers staging
   ↓
Restic
```

`/data/Documents` et `/data/Projets` sont protégés automatiquement par Restic. `/data/ISO` et `/data/Jeux` restent hors backup automatique par défaut.

Voir [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md).

## Interdictions structurantes

- aucun formatage/partitionnement automatique du second T705 ;
- aucune suppression automatique des racines utilisateur `/data` ;
- aucun `chmod 777` ;
- aucun SELinux ou firewalld désactivé ;
- aucun bridge physique automatique ;
- aucun VFIO/passthrough de l'Arc B580 ;
- aucune VM créée pendant `install.sh --apply` ;
- aucun mot de passe invité en clair dans Git ;
- aucune interface Ethernet/Wi-Fi codée en dur ;
- aucun partage VirtioFS HOST↔VM automatique ;
- aucun IPv6 KVM tant qu'une isolation dual-stack équivalente n'est pas certifiée.
