# Virtualisation

Fedora HOST utilise KVM/QEMU/libvirt comme stack de virtualisation de référence. Le réseau `devops-nat` est un NAT privé `192.168.50.0/24`, bridge `virbr50`, DHCP `.100-.200`.

## Objectif

La virtualisation est un domaine prioritaire de la workstation. Le projet doit fournir une stack **complète, propre, fiable et administrable**, sans sacrifier des outils essentiels uniquement pour respecter l'uniformité GTK du bureau.

Le manifeste `manifests/packages-virtualization.txt` conserve donc :

- `qemu-kvm` ;
- `libvirt` ;
- `libvirt-client` ;
- `libvirt-daemon-kvm` ;
- `libvirt-daemon-config-network` ;
- `virt-install` ;
- **`virt-manager`** ;
- **`virt-viewer`** ;
- `edk2-ovmf` ;
- `swtpm` ;
- `guestfs-tools`.

## Exception à la politique GTK4/libadwaita

La règle GTK4/libadwaita s'applique au catalogue applicatif du bureau GNOME général. Elle **ne s'applique pas au scope virtualisation** lorsque cela réduirait les capacités de gestion KVM/libvirt.

`virt-manager` et `virt-viewer` sont donc explicitement autorisés et doivent rester disponibles tant qu'ils constituent les outils Fedora/libvirt appropriés pour l'administration graphique des VM.

Cette exception est volontaire, documentée et strictement limitée aux outils de virtualisation. Elle ne remet pas en cause Ptyxis comme terminal principal ni la politique GTK4/libadwaita des applications desktop.

## GPU

Le GPU Intel Arc B580 reste au HOST : `ALLOW_GPU_PASSTHROUGH=false` est une règle d'architecture. Les VM graphiques utilisent des périphériques virtuels ; les laboratoires DevOps sont destructibles/reproductibles.

## Sécurité et intégration Fedora

La stack doit respecter SELinux, firewalld et les mécanismes libvirt Fedora. Les pools de stockage, réseaux NAT, sockets/services et permissions doivent être configurés sans `chmod 777`, sans désactivation SELinux et sans contournement permanent de la sécurité du HOST.

## VM DevOps

La création automatique d'une VM DevOps reste désactivée tant que HOST + GNOME + KVM ne sont pas validés. Le profil VM sera activé dans une phase dédiée après certification de la stack de virtualisation.
