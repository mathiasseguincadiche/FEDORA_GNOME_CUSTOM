# Virtualisation

Fedora HOST utilise KVM/QEMU/libvirt. Le réseau `devops-nat` est un NAT privé `192.168.50.0/24`, bridge `virbr50`, DHCP `.100-.200`.

Le GPU Intel Arc B580 reste au HOST : `ALLOW_GPU_PASSTHROUGH=false` est une règle d'architecture. Les VM graphiques utilisent des périphériques virtuels ; les laboratoires DevOps sont destructibles/reproductibles.

La création automatique d'une VM DevOps est désactivée en v0.1 (`CREATE_DEVOPS_VM=false`) afin de stabiliser d'abord HOST + GNOME + KVM.
