# Profils VM KVM — contrat de référence

La workstation maintient **exactement deux profils invités de référence**. Ils sont déclaratifs et ne sont jamais créés pendant `install.sh --apply`.

La version applicable est celle de [`../VERSION`](../VERSION). Les valeurs exécutables viennent de [`../config/vm-profiles.conf`](../config/vm-profiles.conf) et [`../config/virtualization.conf`](../config/virtualization.conf). La connexion libvirt canonique est `qemu:///system`.

## Ubuntu Server 26.04 LTS — `ubuntu-devops`

```text
vCPU               6
RAM                16 Gio
disque             160 Gio qcow2
machine            q35
CPU                host-passthrough
firmware           UEFI
bus disque         VirtIO
réseau             VirtIO / devops-nat
graphique          aucun requis
cloud-init         oui
SSH                clé publique uniquement
utilisateur        mathias
mot de passe       runtime, console/sudo
autostart          non
```

### Entrées obligatoires

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
clé SSH publique
pool devops-data actif
réseau devops-nat actif
/data EXT4 monté
```

La liste SHA-256 est authentifiée avec la clé Canonical attendue avant toute création de disque.

### Création

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Le script vérifie l'image Canonical, demande le mot de passe console/sudo, construit le seed cloud-init, embarque les scripts de bootstrap/validation du checkout, crée le disque qcow2 puis la VM avec VirtIO/QGA/RNG/balloon, sans autostart.

Vérification dans le guest :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Accès depuis Fedora : SSH/SFTP. Aucun partage HOST VirtioFS automatique.

## Windows 11 — `windows-11`

```text
vCPU               4
RAM                12 Gio
disque             128 Gio qcow2
machine            q35
CPU                host-passthrough
firmware           UEFI Secure Boot
TPM                2.0 / swtpm
bus disque         VirtIO
réseau             VirtIO / devops-nat
graphique          SPICE + virtio video
autostart          non
```

### Entrées obligatoires

Préparer depuis des sources de confiance :

```text
Windows 11 ISO officiel Microsoft
virtio-win.iso Fedora/Red Hat
SHA-256 Windows de confiance
SHA-256 VirtIO de confiance
```

Le projet ne télécharge aucun de ces médias silencieusement. **Les deux SHA-256 sont des entrées Golden obligatoires.**

### Création

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso \
  --windows-sha256 '<sha256-windows-de-confiance>' \
  --virtio-sha256 '<sha256-virtio-de-confiance>'
```

Le script refuse l'opération si l'un des deux hashes manque ou ne correspond pas au média. Les vérifications ont lieu avant `qemu-img create`.

Le script crée aussi `windows-guest-tools.iso` avec les helpers du projet. Après installation Windows :

1. ouvrir `FGC_TOOLS` ;
2. lancer PowerShell en administrateur ;
3. exécuter `Configure-GuestIntegration.ps1` ;
4. exécuter `Configure-VMShare.ps1` seulement si l'accès SMB via Nautilus est souhaité.

`virtio-win.iso` fournit les pilotes Windows nécessaires au stockage/réseau VirtIO. `SPICE + virtio video` est un affichage virtuel et non un passthrough de la B580.

## Ressources HOST

Le HOST de référence dispose de 8 cœurs / 16 threads et 48 Gio de RAM.

```text
Ubuntu             6 vCPU / 16 Gio
Windows            4 vCPU / 12 Gio
RAM VM totale               28 Gio
HOST restant                ~20 Gio avant consommation dynamique
```

Les vCPU sont sur-allouables ; la configuration reste volontairement modérée.

## Réseau commun

```text
devops-nat
192.168.50.0/24
virbr50
```

HOST↔VM, VM↔VM et VM→Internet sont autorisés. Le forwarding vers le LAN uplink est bloqué par le guard dédié.

Voir [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Cycle de vie recommandé

Démarrer :

```bash
virsh --connect qemu:///system start ubuntu-devops
virsh --connect qemu:///system start windows-11
```

Arrêter proprement :

```bash
virsh --connect qemu:///system shutdown ubuntu-devops
virsh --connect qemu:///system shutdown windows-11
```

Valider :

```bash
bash scripts/kvm/runtime_certification.sh
```

Sauvegarder les disques, VM arrêtées :

```bash
scripts/backup/backup-now.sh --include-vms
```

Pour reconstruire un guest, conserver les données utiles et la sauvegarde, retirer explicitement le domaine/disque concerné selon [`RUNBOOK_KVM.md`](RUNBOOK_KVM.md), puis relancer le script de création correspondant.

## Règles communes

- pool `devops-data` sur `/data/libvirt/images` ;
- réseau `devops-nat` ;
- aucun autostart invité ;
- création opérateur explicite ;
- aucune VM Fedora de référence ;
- aucun VFIO/passthrough de l'Intel Arc B580 ;
- aucun média OS téléchargé automatiquement ;
- aucun mot de passe en clair dans Git ;
- aucun partage HOST VirtioFS automatique ;
- accès Ubuntu via SSH/SFTP ;
- accès fichiers Windows via partage SMB limité lorsque l'opérateur l'active.
