# KVM au quotidien

Créer, utiliser et dépanner la VM Rocky DevOps. L'architecture et le contenu du profil sont dans la [référence virtualisation](VIRTUALIZATION.md), l'isolation réseau dans le [réseau KVM](KVM_NETWORK.md).

Rocky se crée **après** l'installation de Fedora et les premiers contrôles de l'hôte, et **avant** la qualification Golden complète. Le Live USB et l'installation n'exigent aucune VM ; l'APPLY n'en crée jamais.

```text
HOST Fedora
├── connexion libvirt : qemu:///system
├── pool              : devops-data → /data/libvirt/images
├── réseau            : devops-nat  → virbr50 → 192.168.50.0/24
└── VM                : rocky-devops
```

Une règle pour tout ce qui suit : ne jamais désactiver SELinux, firewalld ou le guard nftables pour contourner un problème, ne pas retoucher le XML du domaine au hasard, ne pas copier un QCOW2 en cours d'utilisation comme un fichier ordinaire.

## 1. Vérifier le socle

```bash
./control.sh doctor data
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Attendu : `/dev/kvm`, `kvm_amd`, `qemu:///system`, pool `devops-data`, réseau `devops-nat`, SELinux Enforcing, firewalld, guard nftables, OVMF et swtpm. Le benchmark écrit sur un fichier de `/data`, jamais sur le disque brut.

## 2. Créer Rocky DevOps

Placer l'image, `CHECKSUM` et `CHECKSUM.asc` de la même release dans `/data/libvirt/iso` (détails dans la [référence](VIRTUALIZATION.md#image-source-authentifiée)), puis :

```bash
./control.sh kvm create-rocky \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
```

`CHECKSUM` et `CHECKSUM.asc` sont cherchés à côté de l'image ; sinon, les passer avec `--sha256sums` et `--signature`. Une clé Rocky obtenue par un canal de confiance se passe avec `--rocky-key-file`. Pour vérifier l'image seule avant création : `bash scripts/kvm/verify_rocky_cloud_image.sh --image … --sha256sums … --signature …`.

Le script authentifie l'image **avant** de créer le disque, demande le mot de passe console/sudo sans l'afficher, injecte la clé SSH, génère cloud-init et crée la VM sans autostart. Au premier démarrage, l'invité installe sa stack ; il peut redémarrer une fois pour passer sur le noyau Rocky complet.

## 3. Utiliser

```bash
virsh --connect qemu:///system list --all
virsh --connect qemu:///system start rocky-devops
virsh --connect qemu:///system shutdown rocky-devops     # arrêt propre
virsh --connect qemu:///system domifaddr rocky-devops --source agent
ssh mathias@192.168.50.x
```

`virsh destroy` équivaut à couper l'alimentation : réservé au dépannage. SSH accepte uniquement la clé ; le mot de passe sert à la console et à `sudo`. `virt-manager --connect qemu:///system` reste disponible, mais tout se fait en ligne de commande.

### Fichiers de la VM dans Nautilus

```bash
./control.sh kvm nautilus-refresh
```

Le script découvre l'IP de Rocky (Guest Agent ou bail DHCP) et crée ou met à jour le favori `sftp://mathias@192.168.50.x/home/mathias` dans `~/.config/gtk-3.0/bookmarks`. Relancer après un changement d'IP. Autres actions de `scripts/kvm/configure_nautilus_vm_access.sh` : `show`, `remove` (retire seulement ce favori), `open-rocky`. L'accès garde les permissions réelles de `mathias` ; aucun répertoire du HOST n'est partagé.

### Outils avancés

| Besoin | Outil |
|---|---|
| Cycle de vie, snapshots, réseaux, pools | `virsh` |
| Démons libvirt, validation de l'hôte et des XML | `virt-admin`, `virt-host-validate`, `virt-xml-validate` |
| Créer, cloner, modifier une VM | `virt-install`, `virt-clone`, `virt-xml` |
| Images qcow2 | `qemu-img`, `qemu-io`, `qemu-nbd`, `qemu-storage-daemon` |
| Disques invités hors ligne | `guestfish`, `virt-inspector`, `virt-ls`, `virt-cat`, `virt-edit`, `virt-copy-in/out`, `virt-df`, `virt-diff`, `virt-log` |
| Préparer des modèles | `virt-customize`, `virt-sysprep`, `virt-resize`, `virt-sparsify`, `virt-builder`, `cloud-localds` |
| Surveiller, migrer, QMP | `virt-top`, `virt-v2v`, `virt-qemu-qmp-proxy` |
| Catalogue et firmware | `osinfo-query`, OVMF/UEFI, swtpm |

`libvirt-nss` permet de résoudre les noms des domaines quand le réseau le permet. `virtualization-doctor` vérifie la présence de ces outils.

## 4. Qualifier

```bash
sudo /usr/local/sbin/devops-verify.sh          # dans l'invité
./control.sh kvm certify                         # depuis Fedora
```

La certification demande le mot de passe sudo de la VM dans un terminal SSH. Elle précède la [Gate 3](QUALIFICATION.md).

## 5. Exports

Les exports de la VM sont **manuels**, quand tu le décides : arrêter Rocky, puis garder ensemble disque, XML et NVRAM. Borg ne sauvegarde ni les disques ni le XML libvirt.

## Dépannage

**Socle KVM indisponible.** `ls -l /dev/kvm`, `lsmod | grep kvm_amd`. S'il manque sur le PC, activer AMD-V/SVM dans l'UEFI avant de toucher à Linux.

**Pool `devops-data` absent.** `virsh --connect qemu:///system pool-info devops-data` et `findmnt -T /data` : `/data` doit être le montage EXT4 dédié. Ne pas recréer le pool sur le SSD système pour contourner un second T705 absent ([données `/data`](RUNBOOK_PERSISTENT_DATA_GAMING.md)).

**Réseau `devops-nat` absent.** `virsh --connect qemu:///system net-info devops-nat` et `ip addr show virbr50` : attendu `192.168.50.0/24`, passerelle `192.168.50.254`.

**Guard en mode d'urgence.** `guard_mode=emergency` veut dire que le forwarding est volontairement bloqué. Identifier le changement d'uplink, de VPN ou de route, puis :

```bash
./control.sh kvm guard-check
./control.sh kvm guard-reconcile
./control.sh kvm guard-check      # attendu : guard_mode=normal
```

Si le reconcile échoue, garder le mode d'urgence et diagnostiquer ; ne pas supprimer la table nftables pour retrouver Internet.

**Rocky ne démarre pas.** `virsh --connect qemu:///system dominfo rocky-devops`, `domblklist`, `dumpxml`, `journalctl -u virtqemud -b`. Vérifier `/data/libvirt/images/rocky-devops.qcow2`, le seed cloud-init et le réseau.

**Pas de SSH.** `virsh --connect qemu:///system net-dhcp-leases devops-nat`, puis `ssh -v`. Dans l'invité (console) : `sudo systemctl status qemu-guest-agent`.

**Bootstrap incomplet.** Dans l'invité : `sudo cloud-init status --long`, `sudo systemctl status fgc-devops-bootstrap.service`, `sudo cat /var/log/devops-bootstrap.log`, `sudo /usr/local/sbin/devops-verify.sh`. Ne recréer la VM qu'après avoir sauvé les données utiles et compris l'échec.

**Image refusée.** Image, `CHECKSUM` et `CHECKSUM.asc` doivent venir de la même release Rocky 10.2. Ne jamais contourner la signature ni la comparaison SHA-256 ; ne relancer la création que si le domaine et son disque n'existent pas encore.

**Reconstruire l'invité.** Sauver les données utiles, retirer explicitement le domaine et son disque, puis relancer la création.

**Certification KVM en échec.** Corriger le premier `KO` réel de `virtualization-doctor`, puis relancer. Ne jamais modifier les preuves.
