# Virtualisation — Fedora 44 / KVM / libvirt

## Objectif

La workstation utilise **QEMU/KVM/libvirt** comme stack de virtualisation de référence. Elle est Fedora-native, compatible SELinux/firewalld et conçue autour de deux VM :

- `ubuntu-devops` pour les laboratoires DevOps/Ops ;
- `windows-11` pour les besoins Windows et les tests multi-plateformes.

Le projet est **CLI-first** : `virt-manager` et `virt-viewer` restent disponibles, mais aucune opération essentielle ne dépend de la GUI.

Si KVM/libvirt est nouveau pour vous, lire d'abord [`GLOSSARY.md`](GLOSSARY.md) puis [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md).

## Vue d'ensemble

```text
Fedora 44 HOST
│
├── KVM / QEMU
│   └── exécute les VM avec accélération AMD-V/SVM
│
├── libvirt : qemu:///system
│   ├── domaine ubuntu-devops
│   ├── domaine windows-11
│   ├── pool devops-data
│   └── réseau devops-nat
│
├── /data sur le second T705
│   └── /data/libvirt/images/*.qcow2
│
└── virbr50 / 192.168.50.0/24
    ├── VM ↔ HOST
    ├── VM ↔ VM
    ├── VM → Internet
    └── VM ↔ LAN physique bloqué en forwarding
```

## Qui fait quoi ?

### KVM

KVM fournit l'accélération matérielle dans le noyau Linux. Sur cette plateforme :

```text
AMD-V/SVM → obligatoire
/dev/kvm  → obligatoire
kvm_amd   → obligatoire
```

Sans `/dev/kvm`, le profil bare-metal n'est pas considéré prêt.

### QEMU

QEMU représente la machine virtuelle : CPU virtuel, chipset Q35, disque VirtIO, réseau VirtIO, UEFI, TPM, console, etc.

### libvirt

Libvirt fournit une API et des outils cohérents pour gérer les VM. La connexion de référence est :

```text
qemu:///system
```

Cela signifie que les ressources KVM appartiennent à l'instance libvirt système du HOST.

Le projet privilégie les daemons modulaires Fedora :

```text
virtqemud
virtnetworkd
virtstoraged
virtlogd
virtlockd
```

avec fallback `libvirtd` uniquement lorsque les unités modulaires ne sont pas disponibles.

## GPU

L'Intel Arc B580 reste attachée au HOST Fedora avec le pilote `xe`.

```text
Fedora HOST → Arc B580 / xe
VM          → périphérique vidéo virtuel uniquement
```

Aucun VFIO/passthrough automatique n'est autorisé. Cette décision évite de fragiliser le bureau GNOME principal et le contrat graphique 1440p/240 Hz.

Pour Windows, `SPICE + virtio video` fournit une console de VM adaptée à l'administration, aux tests et à la bureautique. Ce n'est pas l'équivalent d'une B580 directement attribuée au guest.

## Stockage dédié

Le deuxième Crucial T705 est monté manuellement sur :

```text
/data
filesystem : EXT4
```

Le projet ne partitionne et ne formate jamais ce SSD automatiquement.

Arborescence gérée :

```text
/data/libvirt/
├── images/       disques qcow2 des VM
├── iso/          ISO et images cloud fournis par l'opérateur
├── cloud-init/   seeds Ubuntu
├── nvram/        données UEFI si nécessaires
├── snapshots/    espace réservé aux opérations de snapshot
└── exports/      exports/staging liés aux opérations KVM
```

Pool libvirt :

```text
nom       devops-data
type      dir
cible     /data/libvirt/images
autostart oui
```

SELinux reste actif. Le projet persiste le type `virt_image_t` avec `semanage fcontext`, puis applique les labels avec `restorecon`.

Avant de créer les VM :

```bash
./diagnostics/kvm-io-doctor benchmark
```

Le benchmark compare les backends I/O supportés sur `/data` sans écrire sur le block device brut. Les nouvelles VM utilisent ensuite le profil retenu avec `cache=none` et `discard=unmap`; `detect_zeroes` et IOThread ne sont ajoutés que lorsque `virt-install` confirme leur support.

## Réseau privé

Le réseau principal est :

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

Le NAT est fourni par libvirt. L'isolation supplémentaire du LAN est fournie par une table nftables propre au projet.

Le guard ne code pas en dur `enp...` ou `wlp...`. Il redécouvre l'uplink IPv4 courant. Lors d'un changement réseau, il entre d'abord en **mode d'urgence**, qui bloque le forwarding via `virbr50`, puis reconstruit les règles normales. Si la reconstruction échoue, l'état restrictif reste actif.

Explication complète : [`KVM_NETWORK.md`](KVM_NETWORK.md).

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

### Provenance de l'image

La création ne fait plus confiance à une image `.img` uniquement parce que son nom ressemble à une image Ubuntu.

L'opérateur fournit ensemble :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

`create_ubuntu_devops_vm.sh` authentifie `SHA256SUMS` avec l'empreinte Canonical attendue puis compare le SHA-256 de l'image à cette liste signée **avant** de créer le disque de VM.

Création :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

La clé publique SSH est injectée dans le guest. Le mot de passe saisi au terminal est réservé à la console et à `sudo`; SSH reste key-only.

Le bootstrap exact du checkout HOST est encodé dans cloud-init et exécuté dans l'invité.

Voir :

- [`UBUNTU_DEVOPS_READY.md`](UBUNTU_DEVOPS_READY.md) ;
- [`UBUNTU_DEVOPS_PROVISIONING.md`](UBUNTU_DEVOPS_PROVISIONING.md).

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

Création :

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

Le projet ne télécharge silencieusement ni Windows ni `virtio-win.iso`. Les médias sont fournis par l'opérateur depuis leurs sources de confiance.

Le script génère également `windows-guest-tools.iso` avec les helpers d'intégration. Après l'installation, `Configure-GuestIntegration.ps1` installe/valide les pilotes VirtIO et QEMU Guest Agent.

## Accès aux fichiers

Le projet évite un partage de répertoire HOST↔guest automatique.

```text
Fedora / Nautilus
├── SFTP/SSH → ubuntu-devops → /home/mathias
└── SMB      → windows-11   → C:\VM-Share
```

Ubuntu :

```bash
ssh mathias@<ip-de-la-vm>
sftp mathias@<ip-de-la-vm>
```

Nautilus :

```text
sftp://mathias@<ip-de-la-vm>/home/mathias
```

Windows peut exposer uniquement `C:\VM-Share` via le script prévu. Aucun accès invité/anonyme n'est configuré.

Voir [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md).

## Administration quotidienne

Les commandes de base sont documentées dans [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md).

La référence avancée (`virt-admin`, `virt-xml`, `qemu-nbd`, guestfs, virt-v2v, etc.) est séparée dans [`VIRTUALIZATION_CLI.md`](VIRTUALIZATION_CLI.md) afin de ne pas surcharger le parcours débutant.

## Validation

Avant création des VM :

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Après installation des deux VM :

```bash
bash scripts/kvm/runtime_certification.sh
```

La certification vérifie notamment :

- existence des domaines ;
- QEMU Guest Agent ;
- VirtIO RNG et balloon ;
- Secure Boot + TPM Windows ;
- réseau/disque VirtIO ;
- service et règles du guard KVM ;
- retour du guard en mode normal après reconcile ;
- couverture des CIDR uplink détectés ;
- IP Ubuntu/Windows ;
- SSH HOST → Ubuntu ;
- stack DevOps Ubuntu ;
- DNS/HTTPS Internet depuis Ubuntu ;
- accès à la gateway KVM ;
- blocage Ubuntu → gateway LAN lorsque le gateway est d'abord prouvé joignable depuis le HOST.

Une preuve live `LAN → VM` complète nécessite un deuxième appareil du LAN ; elle est guidée dans [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Backup des VM

Un QCOW2 actif ne doit pas être copié avec `cp`, `rsync` ou Restic en espérant obtenir une sauvegarde cohérente.

Le contrat est :

```text
VM arrêtée
   ↓
qemu-img check
   ↓
qemu-img convert vers staging
   ↓
Restic
```

Voir [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md).

## Interdictions structurantes

- aucun formatage/partitionnement automatique du second T705 ;
- aucun `chmod 777` ;
- aucun SELinux désactivé ;
- aucun firewalld désactivé ;
- aucun bridge physique automatique ;
- aucun VFIO/passthrough de l'Arc B580 ;
- aucune VM créée pendant `install.sh --apply` ;
- aucun mot de passe invité en clair dans Git ;
- aucune interface Ethernet/Wi-Fi codée en dur ;
- aucun partage VirtioFS HOST↔VM automatique ;
- aucun IPv6 KVM tant qu'une isolation dual-stack équivalente n'est pas certifiée.
