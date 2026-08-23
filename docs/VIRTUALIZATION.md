# Virtualisation — Fedora 44 / KVM / libvirt

## Objectif

La workstation utilise **QEMU/KVM/libvirt** comme stack de virtualisation de référence. Elle est **CLI-first**, Fedora-native, compatible SELinux/firewalld et conçue autour de deux VM seulement : `ubuntu-devops` et `windows-11`.

La GUI (`virt-manager`, `virt-viewer`, `remote-viewer`) reste disponible, mais aucune opération courante ne dépend d'elle.

## Hyperviseur et administration

Connexion unique :

```text
qemu:///system
```

Le projet privilégie les daemons modulaires libvirt de Fedora (`virtqemud`, `virtnetworkd`, `virtstoraged`, `virtlogd`, `virtlockd`) avec fallback `libvirtd` uniquement si nécessaire.

Outils CLI principaux :

```text
virsh
virt-admin
virt-host-validate
virt-xml-validate
virt-install
virt-clone
virt-xml
qemu-img
qemu-io
qemu-nbd
qemu-storage-daemon
guestfish
virt-filesystems
virt-customize
virt-sysprep
virt-resize
virt-sparsify
virt-builder
virt-top
virt-v2v
virt-qemu-qmp-proxy
cloud-localds
osinfo-query
ssh/scp/sftp/rsync
```

## Accélération et GPU

- AMD-V/SVM et `kvm_amd` sont obligatoires ;
- `/dev/kvm` doit être disponible ;
- l'Intel Arc B580 reste attachée au pilote HOST `xe` ;
- aucun VFIO/passthrough GPU automatique n'est autorisé.

## Stockage dédié

Le second Crucial T705 est monté manuellement :

```text
/data
filesystem : EXT4
```

Le projet ne partitionne et ne formate jamais le SSD.

Arborescence :

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

Pool :

```text
nom       devops-data
type      dir
cible     /data/libvirt/images
autostart oui
```

Les labels SELinux `virt_image_t` sont persistés avec `semanage fcontext` puis appliqués avec `restorecon`.

## Réseau

```text
nom       devops-nat
bridge    virbr50
réseau    192.168.50.0/24
gateway   192.168.50.254
DHCP      192.168.50.100-200
DNS       9.9.9.9 + 1.1.1.1
mode      NAT
zone      firewalld libvirt
```

Contrat :

```text
HOST ↔ VM          autorisé
VM ↔ VM            autorisé
VM → Internet      autorisé
VM → LAN physique  bloqué
LAN → VM           bloqué
Internet → VM      aucun forwarding implicite
```

Le guard nftables `fedora_gnome_custom_kvm` détecte dynamiquement les réseaux physiques. Aucun nom d'interface Ethernet/Wi-Fi n'est codé en dur ; le HOST peut changer de connectivité sans modifier le contrat.

## Profils invités

### `ubuntu-devops`

```text
Ubuntu Server 26.04 LTS
6 vCPU
16 Gio RAM
160 Gio qcow2
Q35 / host-passthrough
UEFI
VirtIO disque/réseau
cloud-init
SSH
VirtioFS /data/libvirt/shared → /mnt/hostshare
memory backing memfd partagé requis
```

Provisionnement :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

La VM reçoit le bootstrap DevOps versionné dans `guest/ubuntu-devops/bootstrap-devops.sh`.

### `windows-11`

```text
Windows 11
4 vCPU
12 Gio RAM
128 Gio qcow2
Q35 / host-passthrough
UEFI Secure Boot
TPM 2.0 swtpm
VirtIO disque/réseau
SPICE + virtio video
```

Provisionnement :

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

`virtio-win.iso` est un média de pilotes VirtIO pour Windows ; il n'est ni un OS ni téléchargé silencieusement par le projet.

## Cloud-init et secrets

Le projet ne stocke aucun mot de passe invité en clair. Le mot de passe Ubuntu est saisi au runtime, hashé en SHA-512, puis seul le hash entre dans le seed cloud-init.

La clé publique SSH est injectée dans `ubuntu-devops`. Le bootstrap est encodé dans le seed et exécuté dans l'invité.

## Validation

Statique/host :

```bash
bash diagnostics/virtualization-doctor
```

Après création des deux VM :

```bash
bash scripts/kvm/runtime_certification.sh
```

La certification automatise ce qui est fiable depuis le HOST (domaines, XML, Ubuntu SSH/DNS/Internet/stack DevOps, HOST↔Ubuntu, blocage Ubuntu→gateway LAN). Les contrôles Windows dépendants de son pare-feu ou de son état d'installation restent explicitement guidés.

## Interdictions

- formatage/partitionnement automatique ;
- `chmod 777` ;
- SELinux désactivé ;
- firewalld désactivé ;
- bridge physique automatique ;
- VFIO/passthrough Arc B580 ;
- VM surprise créée pendant APPLY ;
- mot de passe en clair dans Git ;
- interface physique codée en dur.
