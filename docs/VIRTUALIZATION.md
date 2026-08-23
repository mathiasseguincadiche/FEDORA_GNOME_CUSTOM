# Virtualisation — Fedora 44 / KVM / libvirt

## Objectif

La workstation utilise **KVM/QEMU/libvirt** comme stack de virtualisation de référence. Le scope KVM doit être complet, fiable, Fedora-native, observable, réversible et **CLI-first**. `virt-manager` et `virt-viewer` restent disponibles comme outils complémentaires et constituent des exceptions explicites à la politique GTK4/libadwaita du bureau général.

La connexion de référence est exclusivement :

```text
qemu:///system
```

Le projet ne maintient pas en parallèle un parc `qemu:///session`.

## Stack installée

Le manifeste `manifests/packages-virtualization.txt` couvre :

- QEMU/KVM, `qemu-img`, `qemu-io`, `qemu-nbd` et `qemu-storage-daemon` ;
- libvirt système, client QEMU, NSS et daemons/drivers nécessaires ;
- `virsh`, `virt-admin`, `virt-host-validate` et `virt-xml-validate` ;
- `virt-install`, `virt-clone` et `virt-xml` ;
- `virt-top`, `virt-v2v` et `virt-qemu-qmp-proxy` ;
- OVMF/UEFI ;
- `swtpm`, `swtpm-tools` et la politique SELinux swtpm ;
- `virtiofsd` ;
- `guestfs-tools` et sa chaîne d'inspection/maintenance hors ligne ;
- `cloud-localds` pour les disques NoCloud/cloud-init ;
- `osinfo-db`, `osinfo-db-tools` et `libosinfo` ;
- SSH/SCP/SFTP, rsync et outils de preuve réseau ;
- `virt-manager`, `virt-viewer` et `remote-viewer` ;
- les dépendances du guard réseau et de l'intégration SELinux.

Le détail de la surface CLI et des usages est dans `VIRTUALIZATION_CLI.md`.

## Modèle libvirt Fedora

Le projet privilégie les daemons modulaires de libvirt lorsque Fedora les fournit :

```text
virtqemud.socket      QEMU/KVM
virtnetworkd.socket  réseaux virtuels
virtstoraged.socket  pools/volumes
virtlogd.socket       logs QEMU
virtlockd.socket      verrous
```

`libvirtd.socket` n'est utilisé qu'en fallback si les unités modulaires ne sont réellement pas disponibles.

## Accélération matérielle

Le préflight vérifie :

- AMD-V/SVM ;
- `/dev/kvm` ;
- module `kvm_amd` ;
- validation HOST via `virt-host-validate` ;
- absence de conflit du réseau KVM ;
- firewalld actif ;
- Intel Arc B580 toujours attachée au pilote HOST `xe`.

Le passthrough GPU/VFIO est interdit par architecture :

```text
ALLOW_GPU_PASSTHROUGH=false
VM_PROFILE_GPU_PASSTHROUGH_ALLOWED=false
```

Les invités utilisent des périphériques virtuels. La B580 n'est jamais détachée du HOST automatiquement.

## Stockage dédié — second Crucial T705

Le stockage des VM est séparé du SSD système :

```text
/data                         EXT4 — montage manuel du T705 dédié
└── libvirt/
    ├── images/               disques de VM / pool devops-data
    ├── iso/                  médias d'installation
    ├── cloud-init/           seed/configuration cloud-init
    ├── nvram/                état UEFI
    ├── snapshots/            exports/snapshots opérateur
    ├── exports/              migrations/exports
    └── shared/               racines VirtioFS explicitement choisies
```

Le dépôt **ne partitionne et ne formate jamais** le T705. Avant `--apply`, `/data` doit déjà être un point de montage distinct du filesystem racine et utiliser EXT4.

Le pool libvirt :

```text
nom       devops-data
cible     /data/libvirt/images
type      dir
autostart oui
```

Le projet persiste un contexte SELinux `virt_image_t` avec `semanage fcontext`, puis applique les labels avec `restorecon`. Aucun `chmod 777`, `chcon` permanent ou `setenforce 0` n'est autorisé.

`qemu-img`, `qemu-io`, `qemu-nbd`, `qemu-storage-daemon` et libguestfs permettent ensuite de gérer les images et volumes en ligne de commande sans dépendre d'une GUI.

## UEFI / Secure Boot / TPM

`edk2-ovmf` fournit le firmware UEFI x86_64.

La politique reste **par VM** :

- Ubuntu Server : UEFI ;
- Fedora : UEFI ;
- Windows 11 : UEFI Secure Boot + TPM 2.0 émulé par swtpm.

Les états NVRAM et TPM sont considérés comme des données de VM à préserver lors des sauvegardes/exportations.

## Cloud-init et templates

Le HOST possède les briques nécessaires à une création reproductible en ligne de commande :

```text
virt-install
virt-builder
virt-customize
virt-sysprep
cloud-localds
```

`cloud-localds` permet de créer explicitement un disque NoCloud à partir de user-data/meta-data. Le projet ne télécharge aucune ISO et ne crée aucune VM automatiquement lors de la convergence.

## VirtioFS

`virtiofsd` fait partie de la stack. Les profils Linux peuvent utiliser VirtioFS lorsqu'un partage HOST↔VM est explicitement nécessaire.

Aucun dossier personnel complet n'est partagé automatiquement. Les partages doivent pointer vers une racine dédiée, par exemple `/data/libvirt/shared`.

## Réseau `devops-nat`

Configuration :

```text
nom       devops-nat
bridge    virbr50
réseau    192.168.50.0/24
gateway   192.168.50.254
DHCP      192.168.50.100 → 192.168.50.200
DNS       9.9.9.9 + 1.1.1.1
mode      NAT
firewalld zone = libvirt
```

Contrat réseau :

```text
HOST ↔ VM        autorisé
VM ↔ VM          autorisé
VM → Internet    autorisé
VM → LAN         bloqué
LAN → VM         bloqué
Internet → VM    aucun forwarding entrant par défaut
```

Le bridge libvirt est associé à la zone firewalld `libvirt`. Le projet ne désactive pas firewalld et ne remplace pas sa configuration globale.

### Guard LAN

Le projet possède uniquement sa table nftables :

```text
table inet fedora_gnome_custom_kvm
```

Le guard :

- détecte les sous-réseaux IPv4 directement connectés aux interfaces physiques ;
- refuse un chevauchement avec `192.168.50.0/24` ;
- bloque `virbr50 → LAN physique` ;
- bloque `LAN physique → virbr50` ;
- ne modifie pas les tables firewalld/libvirt existantes ;
- ne bloque ni HOST↔VM, ni VM↔VM ;
- laisse le NAT VM→Internet à libvirt.

Un hook NetworkManager recharge le guard lors des changements de connectivité.

## Catalogue OS

Le projet utilise `osinfo-db`/libosinfo comme source de métadonnées invité. `osinfo-query` fait partie du contrat CLI.

Pour un OS très récent non encore répertorié, `virt-install` peut utiliser la détection du média avec une politique adaptée au lieu de déclarer un faux OS invité.

## Profils VM

Les profils versionnés sont documentés dans `VM_PROFILES.md` :

- Ubuntu Server 26.04 LTS — laboratoire DevOps principal ;
- Fedora 44 — VM Linux de test ;
- Windows 11 — UEFI Secure Boot + TPM 2.0 + VirtIO.

Ils sont **des templates**. `CREATE_DEVOPS_VM=false` reste le comportement par défaut.

## Administration CLI-first

Le contrat impose notamment :

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
cloud-localds
virt-top
virt-v2v
virt-qemu-qmp-proxy
osinfo-query
ssh / scp / sftp / rsync
```

GUI complémentaire :

```text
virt-manager
virt-viewer
remote-viewer
```

## Diagnostic

Le diagnostic principal est :

```bash
bash diagnostics/virtualization-doctor
```

Il vérifie sans modifier : AMD-V/KVM, `virt-host-validate`, propriété HOST de la B580, outils CLI/GUI, modèle libvirt, `qemu:///system`, `/data`, pool `devops-data`, SELinux, OVMF, swtpm, cloud-init tooling, `devops-nat`, DNS, firewalld, guard LAN, libosinfo et profils VM.

## Limite volontaire de la validation statique

Le dépôt peut vérifier l'architecture sans créer de VM. Les preuves suivantes exigent des invités réellement démarrés :

```text
HOST ↔ VM réel
VM ↔ VM réel
VM → Internet réel
DNS depuis VM
VM → LAN réellement bloqué
```

Ces tests constituent la **certification runtime KVM sur machine réelle**. Leur absence ne déclenche jamais la création automatique de VM.

## Sécurité

Sont interdits : VFIO automatique, passthrough de la B580, `chmod 777`, `setenforce 0`, formatage automatique du SSD, bridge physique automatique, port forwarding entrant implicite et écrasement automatique d'un réseau libvirt existant mais incompatible.

Le principe reste : **détecter → valider → configurer → vérifier → diagnostiquer**.
