# Runbook — KVM / libvirt / VM

Ce runbook part des symptômes. Il complète [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md), [`VIRTUALIZATION.md`](VIRTUALIZATION.md) et [`KVM_NETWORK.md`](KVM_NETWORK.md).

## Règles de sécurité

Ne pas résoudre un problème KVM en désactivant SELinux, firewalld ou le guard nftables. Ne pas modifier au hasard le XML d'un domaine Golden. Ne pas copier un QCOW2 actif comme un fichier ordinaire.

## Socle KVM indisponible

```bash
./diagnostics/virtualization-doctor
ls -l /dev/kvm
lsmod | grep kvm_amd
virsh --connect qemu:///system list --all
```

Si `/dev/kvm` ou `kvm_amd` manque sur le bare-metal, vérifier AMD-V/SVM dans l'UEFI avant de modifier Linux.

## Pool `devops-data` absent ou inactif

```bash
./control.sh doctor data
virsh --connect qemu:///system pool-list --all
virsh --connect qemu:///system pool-info devops-data
findmnt -T /data
```

Attendu : `/data` est un montage EXT4 dédié et `devops-data` pointe vers `/data/libvirt/images`.

Ne pas recréer le pool sur le SSD système pour contourner un second T705 absent.

## Réseau `devops-nat` absent

```bash
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system net-info devops-nat
ip addr show virbr50
./diagnostics/virtualization-doctor
```

Attendu : `virbr50`, réseau `192.168.50.0/24`, gateway `192.168.50.254`.

## Guard KVM en mode d'urgence

Utiliser la façade publique du projet afin de charger la configuration versionnée :

```bash
systemctl status fedora-gnome-custom-kvm-guard.service
./control.sh kvm guard-check
```

`guard_mode=emergency` signifie que le forwarding reste volontairement bloqué. Identifier d'abord le changement d'uplink/VPN/route, puis demander un reconcile :

```bash
./control.sh kvm guard-reconcile
./control.sh kvm guard-check
```

L'état attendu après réparation est `guard_mode=normal`. Si le reconcile échoue, conserver le mode d'urgence et diagnostiquer ; ne pas supprimer la table nftables pour récupérer Internet.

## Rocky DevOps ne démarre pas

```bash
virsh --connect qemu:///system dominfo rocky-devops
virsh --connect qemu:///system domblklist rocky-devops
virsh --connect qemu:///system dumpxml rocky-devops
journalctl -u virtqemud -b --no-pager 2>/dev/null || true
```

Vérifier le disque `/data/libvirt/images/rocky-devops.qcow2`, le seed cloud-init et le réseau `devops-nat`.

## Rocky Linux inaccessible en SSH

```bash
virsh --connect qemu:///system domifaddr rocky-devops --source agent
virsh --connect qemu:///system net-dhcp-leases devops-nat
ssh -v mathias@192.168.50.x
```

SSH est key-only. Le mot de passe saisi à la création sert à la console et à `sudo`, pas à l'authentification SSH.

Dans le guest :

```bash
sudo systemctl status qemu-guest-agent
sudo /usr/local/sbin/devops-verify.sh
```

## Cloud-init / bootstrap Rocky Linux incomplet

Dans le guest :

```bash
sudo cloud-init status --long
sudo cat /var/log/devops-bootstrap.log
sudo /usr/local/sbin/devops-verify.sh
```

Ne recréer la VM qu'après avoir conservé les données utiles et compris l'échec.

## Image Rocky Linux refusée

La création exige l'image, `CHECKSUM` et `CHECKSUM.asc` authentifiés.

```bash
bash scripts/kvm/verify_rocky_cloud_image.sh --help
```

Après avoir préparé ensemble l’image, `CHECKSUM` et sa signature `CHECKSUM.asc`, la commande de création est :

```bash
bash scripts/kvm/create_rocky_devops_vm.sh \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2 \
  --sha256sums /data/libvirt/iso/CHECKSUM \
  --signature /data/libvirt/iso/CHECKSUM.asc
```

Ne relancer la création que si le domaine et son disque n’existent pas encore. Ne contourner ni la signature Rocky Linux ni la comparaison SHA-256.

## Export manuel des VM

La VM Rocky Linux est exportée **manuellement par le propriétaire**,
quand il en a besoin. Les sauvegardes Borg du projet concernent uniquement le
système Fedora et les données utilisateur. Ni le Control Center, ni l'upgrade
Fedora 45, ni les timers Borg ne sauvegardent des disques QCOW2 ou XML libvirt.

La validation des VM par `virsh` et les tests KVM restent indépendants de
l'existence d'un export personnel. Aucun arrêt automatique des VM n'est
demandé par le moteur de sauvegarde Borg.

## Certification KVM échoue

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
bash scripts/kvm/runtime_certification.sh
```

Corriger le premier KO réel. La certification vérifie aussi l'isolation réseau et ne doit pas être forcée en modifiant les preuves.
