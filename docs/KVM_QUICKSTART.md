# KVM Quickstart — utilisation quotidienne

Ce document est le point d'entrée KVM pour quelqu'un qui ne connaît pas encore libvirt. Pour comprendre l'architecture en détail, lire ensuite [`VIRTUALIZATION.md`](VIRTUALIZATION.md) et [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Les quatre objets à retenir

```text
HOST Fedora
├── connexion libvirt : qemu:///system
├── pool stockage     : devops-data → /data/libvirt/images
├── réseau            : devops-nat  → virbr50 → 192.168.50.0/24
└── VM
    ├── ubuntu-devops
    └── windows-11
```

Une **VM** est appelée un *domaine* par libvirt. Un **pool** est un emplacement de stockage connu de libvirt. Un **réseau** fournit la connectivité privée des VM.

## Vérifier que KVM est prêt

```bash
./diagnostics/virtualization-doctor
```

Avant de créer les VM, le résultat doit confirmer notamment :

- `/dev/kvm` disponible ;
- `kvm_amd` chargé ;
- libvirt accessible sur `qemu:///system` ;
- pool `devops-data` disponible ;
- réseau `devops-nat` actif ;
- SELinux Enforcing ;
- firewalld actif ;
- guard nftables chargé ;
- OVMF et swtpm disponibles.

Pour le second T705 :

```bash
./diagnostics/kvm-io-doctor benchmark
```

Le benchmark est filesystem-safe sur `/data` et sélectionne le backend I/O adapté aux nouvelles VM.

## Commandes quotidiennes

Lister les VM :

```bash
virsh --connect qemu:///system list --all
```

Démarrer Ubuntu :

```bash
virsh --connect qemu:///system start ubuntu-devops
```

Arrêter proprement Ubuntu :

```bash
virsh --connect qemu:///system shutdown ubuntu-devops
```

Forcer l'arrêt avec `destroy` équivaut à couper brutalement l'alimentation virtuelle. Ne l'utiliser qu'en dépannage :

```bash
virsh --connect qemu:///system destroy ubuntu-devops
```

Afficher le réseau :

```bash
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system net-info devops-nat
virsh --connect qemu:///system net-dhcp-leases devops-nat
```

Afficher le stockage :

```bash
virsh --connect qemu:///system pool-list --all
virsh --connect qemu:///system pool-info devops-data
virsh --connect qemu:///system vol-list devops-data
```

## Créer Ubuntu DevOps

Télécharger depuis le répertoire de release officiel Canonical les trois fichiers correspondants :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

Les conserver dans le même dossier, puis :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Le script :

1. authentifie `SHA256SUMS` avec la clé Canonical attendue ;
2. vérifie le SHA-256 de l'image ;
3. demande le mot de passe console/sudo sans l'afficher ;
4. injecte la clé SSH ;
5. génère cloud-init ;
6. crée le disque qcow2 ;
7. crée la VM sans autostart ;
8. laisse le bootstrap DevOps s'exécuter au premier démarrage.

Si la clé Canonical ne peut pas être récupérée depuis le keyserver, utiliser une copie locale préalablement obtenue et vérifiée :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img \
  --canonical-key-file /chemin/cle-canonical.asc
```

## Se connecter à Ubuntu

Trouver l'adresse IP :

```bash
virsh --connect qemu:///system domifaddr ubuntu-devops --source agent
```

Si QEMU Guest Agent n'est pas encore prêt :

```bash
virsh --connect qemu:///system net-dhcp-leases devops-nat
```

Connexion :

```bash
ssh mathias@192.168.50.x
```

SSH utilise la clé publique injectée. Le mot de passe créé pendant le provisioning sert à la console et à `sudo`, pas à l'authentification SSH.

Dans Nautilus :

```text
sftp://mathias@192.168.50.x/home/mathias
```

Le helper peut créer/mettre à jour le favori automatiquement :

```bash
bash scripts/kvm/configure_nautilus_vm_access.sh refresh
```

## Créer Windows 11

Préparer :

```text
Windows 11 ISO officiel Microsoft
virtio-win.iso provenant de la source Fedora/Red Hat de confiance
```

Puis :

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

Après l'installation de Windows :

1. ouvrir le CD `FGC_TOOLS` ;
2. lancer PowerShell en administrateur ;
3. exécuter `Configure-GuestIntegration.ps1` ;
4. exécuter `Configure-VMShare.ps1` uniquement si l'accès SMB depuis Nautilus est souhaité.

`SPICE + virtio video` fournit une console de VM adaptée à l'administration, à la bureautique et aux tests. Cela ne remplace pas un GPU physique passé directement à Windows. Le projet interdit volontairement le passthrough de l'Arc B580.

## Interface graphique

`virt-manager` reste disponible :

```bash
virt-manager --connect qemu:///system
```

La GUI est un complément. Les opérations essentielles doivent rester réalisables en CLI.

## Certifier les deux VM

Lorsque Ubuntu et Windows sont installés et démarrés :

```bash
bash scripts/kvm/runtime_certification.sh
```

La certification vérifie notamment QEMU Guest Agent, VirtIO, réseau, accès Ubuntu, Internet, stack DevOps, guard KVM et blocage du LAN physique lorsque la preuve live est possible.

## Avant une sauvegarde des disques VM

Arrêter les VM :

```bash
virsh --connect qemu:///system shutdown ubuntu-devops
virsh --connect qemu:///system shutdown windows-11
```

Vérifier :

```bash
virsh --connect qemu:///system list --all
```

Puis :

```bash
scripts/backup/backup-now.sh --include-vms
```

Le projet refuse volontairement de sauvegarder un QCOW2 actif avec une simple copie de fichier.

## Si quelque chose ne fonctionne pas

Lire [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md), section KVM/VM, avant de modifier firewalld, SELinux ou le XML libvirt.
