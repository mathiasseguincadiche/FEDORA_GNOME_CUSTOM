# Profils VM KVM

Les profils définis dans `config/vm-profiles.conf` sont des **templates déclaratifs**. Ils ne créent aucune VM pendant l'installation de la workstation.

## Ubuntu Server 26.04 LTS — `ubuntu-devops`

Usage : laboratoire DevOps/Ops principal.

```text
vCPU          6
RAM           12 Gio
disque        120 Gio qcow2
machine       q35
CPU           host-passthrough
firmware      UEFI
disque bus    VirtIO
réseau        VirtIO / devops-nat
graphique     aucun requis
cloud-init    oui
VirtioFS      disponible
autostart     non
```

Ce profil est destiné à héberger la future couche `VM_DEVOPS` : Docker, Kubernetes, IaC, Ansible et outils cloud restent isolés du HOST lorsqu'ils n'ont pas de raison d'être installés directement sur Fedora.

## Fedora 44 — `fedora-lab`

Usage : tests Linux, validation de versions et laboratoires secondaires.

```text
vCPU          4
RAM           8 Gio
disque        80 Gio qcow2
machine       q35
CPU           host-passthrough
firmware      UEFI
disque bus    VirtIO
réseau        VirtIO / devops-nat
graphique     SPICE + virtio-gpu
3D            désactivée par défaut
VirtioFS      disponible
autostart     non
```

L'accélération 3D n'est pas forcée. Elle pourra être activée pour un invité précis après validation, sans passthrough de l'Intel Arc B580.

## Windows 11 — `windows-11`

Usage : VM Windows générale et tests multi-plateformes.

```text
vCPU          8
RAM           16 Gio
disque        160 Gio qcow2
machine       q35
CPU           host-passthrough
firmware      UEFI Secure Boot
TPM           2.0 / swtpm
disque bus    VirtIO
réseau        VirtIO / devops-nat
graphique     SPICE + virtio-gpu
VirtioFS      non par défaut
autostart     non
```

Les pilotes Windows VirtIO ne sont pas téléchargés silencieusement par le projet. Le profil exige un média VirtIO Windows obtenu explicitement depuis une source approuvée par l'opérateur.

## Règles communes

- pool par défaut : `devops-data` ;
- réseau par défaut : `devops-nat` ;
- aucun autostart par défaut ;
- création interactive uniquement ;
- aucune VM créée pendant `install.sh --apply` ;
- aucun VFIO/passthrough GPU ;
- l'Intel Arc B580 reste au HOST ;
- les images de disque résident sur le T705 dédié ;
- les partages VirtioFS sont explicitement déclarés et ne pointent jamais automatiquement vers tout le `$HOME`.
