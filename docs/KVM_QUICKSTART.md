# KVM Quickstart — utilisation quotidienne

Ce document est le parcours opérateur court pour KVM/libvirt. Pour l'architecture détaillée, lire ensuite [`VIRTUALIZATION.md`](VIRTUALIZATION.md). Pour le dépannage, utiliser [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md).

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

Une VM est un *domaine* libvirt. Le pool pointe vers le second T705. Le réseau `devops-nat` autorise HOST↔VM, VM↔VM et VM→Internet, tout en bloquant le forwarding vers le LAN physique.

## 1. Vérifier que le socle est prêt

```bash
./control.sh doctor data
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Avant création des VM, attendre notamment : `/dev/kvm`, `kvm_amd`, `qemu:///system`, pool `devops-data`, réseau `devops-nat`, SELinux Enforcing, firewalld, guard nftables, OVMF et swtpm.

Le benchmark I/O travaille sur le filesystem `/data`; il n'écrit jamais sur le block device brut.

## 2. Commandes quotidiennes

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system net-info devops-nat
virsh --connect qemu:///system net-dhcp-leases devops-nat
virsh --connect qemu:///system pool-info devops-data
virsh --connect qemu:///system vol-list devops-data
```

Démarrer/arrêter proprement :

```bash
virsh --connect qemu:///system start ubuntu-devops
virsh --connect qemu:///system shutdown ubuntu-devops
virsh --connect qemu:///system start windows-11
virsh --connect qemu:///system shutdown windows-11
```

`virsh destroy` équivaut à une coupure d'alimentation virtuelle et reste un geste de dépannage.

## 3. Créer Ubuntu DevOps

Préparer ensemble depuis Canonical :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

Puis :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Le script authentifie `SHA256SUMS`, vérifie le SHA-256 de l'image **avant** la création du disque, demande le mot de passe console/sudo sans l'afficher, injecte la clé SSH, génère cloud-init et crée la VM sans autostart.

Si la clé Canonical doit être fournie localement :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img \
  --canonical-key-file /chemin/cle-canonical.asc
```

Accès :

```bash
virsh --connect qemu:///system domifaddr ubuntu-devops --source agent
ssh mathias@192.168.50.x
```

Nautilus :

```text
sftp://mathias@192.168.50.x/home/mathias
```

Le helper peut maintenir le favori :

```bash
bash scripts/kvm/configure_nautilus_vm_access.sh refresh
```

## 4. Créer Windows 11

Préparer depuis des sources de confiance :

```text
Windows 11 ISO officiel Microsoft
virtio-win.iso Fedora/Red Hat
SHA-256 Windows obtenu depuis une source de confiance
SHA-256 VirtIO obtenu depuis une source de confiance
```

Les **deux SHA-256 sont obligatoires**. Le script refuse toute création si l'un des deux manque.

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso \
  --windows-sha256 '<sha256-windows-de-confiance>' \
  --virtio-sha256 '<sha256-virtio-de-confiance>'
```

Les médias sont vérifiés avant `qemu-img create`. Calculer soi-même le hash d'un fichier déjà téléchargé ne prouve que son intégrité locale, pas sa provenance.

Le script génère également `windows-guest-tools.iso`. Après installation :

1. ouvrir le CD `FGC_TOOLS` ;
2. lancer PowerShell en administrateur ;
3. exécuter `Configure-GuestIntegration.ps1` ;
4. exécuter `Configure-VMShare.ps1` uniquement si l'accès SMB depuis Nautilus est souhaité.

Windows utilise UEFI Secure Boot, TPM 2.0/swtpm, VirtIO, QEMU Guest Agent et `SPICE + virtio video`. L'Arc B580 reste réservée au HOST.

## 5. Interface graphique

```bash
virt-manager --connect qemu:///system
```

La GUI est un complément. Le cycle de vie de référence reste réalisable en CLI.

## 6. Certifier les VM

Quand Ubuntu et Windows sont installés et démarrés :

```bash
bash scripts/kvm/runtime_certification.sh
```

La certification contrôle notamment QEMU Guest Agent, VirtIO, Secure Boot/TPM Windows, réseau, stack DevOps Ubuntu, Internet et guard KVM.

## 7. Sauvegarder les VM

Arrêter les deux domaines puis vérifier leur état :

```bash
virsh --connect qemu:///system shutdown ubuntu-devops
virsh --connect qemu:///system shutdown windows-11
virsh --connect qemu:///system list --all
```

Puis :

```bash
scripts/backup/backup-now.sh --include-vms
```

Le projet refuse la copie naïve d'un QCOW2 actif.

## 8. En cas de problème

Ne pas désactiver SELinux, firewalld ou le guard pour contourner un symptôme.

- KVM/libvirt/réseau/VM : [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md) ;
- second T705, `/data`, jeux : [`RUNBOOK_PERSISTENT_DATA_GAMING.md`](RUNBOOK_PERSISTENT_DATA_GAMING.md) ;
- dépannage transversal : [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
