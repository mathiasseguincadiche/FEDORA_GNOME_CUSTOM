# Virtualisation — Fedora 44 / KVM / libvirt

## Objectif

La workstation utilise **KVM/QEMU/libvirt** comme stack de virtualisation de référence. Le scope KVM doit être complet, fiable, Fedora-native, observable et réversible sans sacrifier des fonctions importantes pour une règle esthétique du bureau.

`virt-manager` et `virt-viewer` restent donc des exceptions explicites à la politique GTK4/libadwaita des applications desktop.

## Stack installée

Le manifeste `manifests/packages-virtualization.txt` couvre :

- QEMU/KVM et `qemu-img` ;
- libvirt système et ses drivers KVM/réseau/stockage ;
- `virsh`, `virt-install` et `virt-clone` ;
- `virt-manager`, `virt-viewer` et `remote-viewer` ;
- OVMF/UEFI ;
- `swtpm`, `swtpm-tools` et la politique SELinux swtpm ;
- `virtiofsd` ;
- `guestfs-tools` ;
- `osinfo-db`, `osinfo-db-tools` et `libosinfo` ;
- les dépendances du guard réseau et de l'intégration SELinux.

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

La connexion de référence est exclusivement :

```text
qemu:///system
```

Le projet n'entretient pas en parallèle un second parc de VM sous `qemu:///session`.

## Accélération matérielle

Le préflight vérifie :

- AMD-V/SVM ;
- `/dev/kvm` ;
- module `kvm_amd` ;
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

Le stockage des VM est séparé du SSD système.

Configuration de référence :

```text
/data                         EXT4 — montage manuel du T705 dédié
└── libvirt/
    ├── images/               disques de VM / pool devops-data
    ├── iso/                  médias d'installation
    ├── cloud-init/           seed/configuration cloud-init
    ├── nvram/                état UEFI à exporter/sauvegarder
    ├── snapshots/            exports/snapshots opérateur
    ├── exports/              migrations/exports
    └── shared/               racines VirtioFS explicitement choisies
```

Le dépôt **ne partitionne et ne formate jamais** le T705. Avant `--apply`, `/data` doit déjà être un point de montage distinct du filesystem racine et utiliser EXT4.

Le pool libvirt :

```text
nom    : devops-data
cible  : /data/libvirt/images
type   : dir
autostart : oui
```

Le projet persiste un contexte SELinux `virt_image_t` avec `semanage fcontext`, puis applique les labels avec `restorecon`. Aucun `chmod 777`, `chcon` permanent ou `setenforce 0` n'est autorisé.

## UEFI / Secure Boot / TPM

`edk2-ovmf` fournit le firmware UEFI utilisé par les invités x86_64.

La politique reste **par VM** :

- Ubuntu Server : UEFI ;
- Fedora : UEFI ;
- Windows 11 : UEFI Secure Boot + TPM 2.0 émulé par swtpm.

Le module vérifie la présence des descripteurs/firmwares OVMF et les capacités libvirt. Les états NVRAM et TPM sont considérés comme des données de VM à préserver lors des sauvegardes/exportations.

## VirtioFS

`virtiofsd` fait partie de la stack. Les profils Linux peuvent utiliser VirtioFS lorsqu'un partage HOST↔VM est explicitement nécessaire.

Aucun dossier personnel complet n'est partagé automatiquement. Les partages doivent pointer vers une racine dédiée et contrôlée, par exemple `/data/libvirt/shared`.

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

### Intégration firewalld

Le bridge libvirt est explicitement associé à la zone firewalld `libvirt`. Le projet ne désactive pas firewalld et ne remplace pas sa configuration globale.

### Guard LAN

Le NAT libvirt seul autoriserait normalement un invité à joindre les réseaux routables du HOST. Le projet ajoute donc un **guard nftables possédé uniquement par le projet** :

```text
table inet fedora_gnome_custom_kvm
```

Le guard :

- détecte les sous-réseaux IPv4 directement connectés aux interfaces physiques ;
- refuse un chevauchement avec `192.168.50.0/24` ;
- bloque le forwarding `virbr50 → LAN physique` ;
- bloque le forwarding `LAN physique → virbr50` ;
- ne modifie pas les tables firewalld/libvirt existantes ;
- ne bloque pas les communications HOST↔VM ;
- ne bloque pas le trafic VM↔VM ;
- laisse le NAT VM→Internet géré par libvirt.

Un hook NetworkManager recharge ce guard lors des changements de connectivité afin que le jeu de réseaux physiques ne reste pas figé après le boot.

## Catalogue OS

Le projet utilise `osinfo-db`/libosinfo comme source de métadonnées invité plutôt qu'une copie statique maintenue dans le dépôt.

Pour une version extrêmement récente non encore répertoriée par la base Fedora, la création manuelle peut utiliser la détection de média de `virt-install` avec une politique `require=off` plutôt que de mentir sur l'OS invité.

Aucune ISO n'est téléchargée automatiquement par le module KVM.

## Profils VM

Les profils versionnés sont documentés dans `VM_PROFILES.md` :

- Ubuntu Server 26.04 LTS — laboratoire DevOps principal ;
- Fedora 44 — VM Linux de test ;
- Windows 11 — UEFI Secure Boot + TPM 2.0 + VirtIO.

Ils sont **des templates**. `CREATE_DEVOPS_VM=false` reste le comportement par défaut : une convergence de la workstation ne crée jamais une VM surprise.

## Outils d'administration

CLI supportée :

```text
virsh
virt-install
virt-clone
qemu-img
guestfish
virt-filesystems
osinfo-query
```

GUI supportée :

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

Il vérifie sans modifier :

- AMD-V/KVM ;
- propriété HOST de la B580 ;
- outils installés ;
- modèle de daemon libvirt ;
- connexion `qemu:///system` ;
- `/data` et le pool `devops-data` ;
- SELinux ;
- OVMF et swtpm ;
- `devops-nat` ;
- DNS ;
- firewalld ;
- guard LAN ;
- libosinfo ;
- profils VM.

## Limite volontaire de la validation statique

Le dépôt peut vérifier toute l'architecture sans créer de VM. En revanche, les preuves suivantes exigent au moins un ou deux invités réellement démarrés sur la workstation :

```text
HOST ↔ VM réel
VM ↔ VM réel
VM → Internet réel
DNS depuis VM
VM → LAN réellement bloqué
```

Ces tests constituent la **certification runtime KVM sur machine réelle**. Leur absence ne déclenche pas la création automatique de VM ; elle est signalée comme preuve runtime à effectuer après installation.

## Sécurité

Sont interdits :

- VFIO automatique ;
- passthrough de la B580 ;
- `chmod 777` ;
- `setenforce 0` ;
- formatage automatique du SSD ;
- bridge physique automatique ;
- port forwarding entrant implicite ;
- écrasement automatique d'un réseau libvirt existant mais incompatible.

Le principe reste : **détecter → valider → configurer → vérifier → diagnostiquer**.
