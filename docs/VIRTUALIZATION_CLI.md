# Virtualisation CLI — Fedora 44 / KVM / libvirt

## Positionnement

La virtualisation de la workstation est **CLI-first**. `virt-manager` et `virt-viewer` restent disponibles, mais aucune opération courante d'administration ne doit dépendre de l'interface graphique.

La connexion libvirt de référence est :

```text
qemu:///system
```

## Outils de cycle de vie et validation

| Besoin | Outil |
|---|---|
| Lister, démarrer, arrêter, suspendre, snapshots, réseaux, pools | `virsh` |
| Administrer les daemons libvirt | `virt-admin` |
| Valider le HOST KVM/libvirt | `virt-host-validate` |
| Valider un XML libvirt | `virt-xml-validate` |
| Créer une VM | `virt-install` |
| Cloner une VM | `virt-clone` |
| Modifier proprement le XML d'une VM | `virt-xml` |
| Inspecter/convertir/redimensionner qcow2 | `qemu-img` |
| I/O bas niveau sur images | `qemu-io` |
| Exposer une image en NBD | `qemu-nbd` |
| Service de stockage QEMU | `qemu-storage-daemon` |
| Générer un disque NoCloud/cloud-init | `cloud-localds` |
| Monitoring temps réel des domaines | `virt-top` |
| Conversion/migration d'autres hyperviseurs | `virt-v2v` |
| Accès QEMU/QMP avancé | `virt-qemu-qmp-proxy` |

## Manipulation hors ligne des disques invités

`guestfs-tools` et libguestfs fournissent notamment :

```text
guestfish
virt-filesystems
virt-inspector
virt-ls
virt-cat
virt-edit
virt-log
virt-tail
virt-customize
virt-sysprep
virt-resize
virt-sparsify
virt-builder
virt-df
virt-diff
virt-copy-in
virt-copy-out
```

Ces outils permettent de manipuler, préparer, inspecter et maintenir les images de VM sans démarrer l'invité lorsque l'opération le permet.

## Cloud-init et templates

`cloud-utils-cloud-localds` fournit `cloud-localds` pour générer explicitement des disques NoCloud. Combiné à `virt-install --cloud-init`, `virt-builder`, `virt-customize` et `virt-sysprep`, le HOST possède une chaîne complète pour créer et préparer des VM reproductibles en ligne de commande sans télécharger ni créer automatiquement une VM pendant la convergence de la workstation.

## Administration réseau et accès invités

Le HOST dispose de :

```text
ssh
scp
sftp
rsync
ping
```

`libvirt-nss` est installé afin de fournir le support NSS de résolution des noms de domaines libvirt lorsque la configuration réseau le permet.

Le réseau principal reste `devops-nat` sur `virbr50`, avec isolation du LAN physique gérée par le projet.

## Catalogue, firmware et partage

```text
osinfo-query
OVMF / UEFI
swtpm / TPM 2.0
virtiofsd
```

Windows 11 conserve son profil UEFI Secure Boot + TPM 2.0 ; les profils Linux utilisent UEFI et peuvent utiliser VirtioFS.

## GUI complémentaire

```text
virt-manager
virt-viewer
remote-viewer
```

La GUI est complémentaire. Le contrat exige que le cycle de vie, la création, le clonage, la modification XML, le stockage, les snapshots, les inspections disque, les templates cloud-init et les principales opérations de maintenance soient possibles en ligne de commande.

## Validation

`diagnostics/virtualization-doctor` vérifie le jeu d'outils CLI ainsi que KVM, libvirt, le stockage, SELinux, OVMF, swtpm, le réseau et l'isolation.

La CI impose notamment `virt-admin`, `virt-host-validate`, `virt-xml-validate`, `virt-xml`, `qemu-io`, `qemu-nbd`, `qemu-storage-daemon`, `virt-customize`, `virt-sysprep`, `virt-resize`, `virt-sparsify`, `virt-builder`, `cloud-localds`, `virt-top`, `virt-v2v`, `virt-qemu-qmp-proxy` et `rsync`.
