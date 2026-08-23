# Profils VM KVM — contrat final

La workstation maintient **exactement deux profils invités de référence**. Ils sont déclaratifs et ne sont jamais créés pendant `install.sh --apply`.

## Ubuntu Server 26.04 LTS — `ubuntu-devops`

VM principale pour les laboratoires DevOps/Ops.

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
SSH                oui, clé publique prioritaire
utilisateur        mathias
mot de passe       demandé au runtime, jamais versionné
VirtioFS source    /data/libvirt/shared
memory backing     memfd / shared
VirtioFS tag       hostshare
montage invité     /mnt/hostshare
autostart          non
```

Création explicite :

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Le script génère un hash SHA-512 du mot de passe saisi, construit le seed cloud-init, embarque les scripts de bootstrap/validation dans le seed et crée la VM avec `virt-install`.

Le bootstrap invité installe Git/GitHub CLI, Docker Engine + Compose/Buildx, Ansible, Terraform, Azure CLI, AWS CLI v2, kubectl, Helm, kind, Python et les utilitaires d'exploitation.

## Windows 11 — `windows-11`

VM secondaire pour les besoins Windows et les tests multi-plateformes.

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
graphique          SPICE + virtio
VirtioFS           non par défaut
autostart          non
```

Création explicite :

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso
```

`virtio-win.iso` contient les pilotes Windows nécessaires au stockage/réseau VirtIO. Le projet ne télécharge jamais ce média silencieusement.

## Ressources HOST

Le HOST de référence dispose de 8 cœurs / 16 threads et 48 Gio de RAM. Avec les deux VM démarrées :

```text
Ubuntu    6 vCPU / 16 Gio
Windows   4 vCPU / 12 Gio
VM RAM totale      28 Gio
HOST restant       ~20 Gio avant consommation dynamique
```

Les vCPU sont sur-allouables par KVM ; la configuration évite toutefois de monopoliser tous les threads du HOST.

## Règles communes

- pool : `devops-data` sur `/data/libvirt/images` ;
- réseau : `devops-nat` / `192.168.50.0/24` ;
- aucun autostart invité ;
- création opérateur explicite ;
- aucune VM Fedora de référence ;
- aucun VFIO/passthrough de l'Intel Arc B580 ;
- aucune ISO ni image cloud téléchargée automatiquement ;
- aucun mot de passe en clair dans Git ;
- les partages VirtioFS restent limités à `/data/libvirt/shared`.
