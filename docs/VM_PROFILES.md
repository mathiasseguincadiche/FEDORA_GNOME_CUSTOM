# Profils VM KVM — contrat de référence

La workstation maintient **un seul profil invité de référence : Rocky Linux 10.2**. Il est déclaratif et n’est jamais créé pendant `install.sh --apply`.

La version applicable est celle de [`../VERSION`](../VERSION). Les valeurs exécutables viennent de [`../config/vm-profiles.conf`](../config/vm-profiles.conf) et [`../config/virtualization.conf`](../config/virtualization.conf). La connexion libvirt canonique est `qemu:///system`.

## Rocky Linux 10.2 — `rocky-devops`

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
Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
CHECKSUM
CHECKSUM.asc
clé SSH publique
pool devops-data actif
réseau devops-nat actif
/data EXT4 monté
```

La liste SHA-256 est authentifiée avec la clé Rocky Linux attendue avant toute création de disque.

### Création

```bash
bash scripts/kvm/create_rocky_devops_vm.sh \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
```

Le script vérifie l'image Rocky Linux, demande le mot de passe console/sudo, construit le seed cloud-init, embarque les scripts de bootstrap/validation du checkout, crée le disque qcow2 puis la VM avec VirtIO/QGA/RNG/balloon, sans autostart.

Vérification dans le guest :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Accès depuis Fedora : SSH/SFTP. Aucun partage HOST VirtioFS automatique.

## Ressources HOST

Le HOST de référence dispose de 8 cœurs / 16 threads et 48 Gio de RAM.

```text
Rocky Linux             6 vCPU / 16 Gio
RAM VM totale               16 Gio
HOST restant                ~32 Gio avant consommation du système et des applications
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
virsh --connect qemu:///system start rocky-devops
```

Arrêter proprement :

```bash
virsh --connect qemu:///system shutdown rocky-devops
```

Valider :

```bash
bash scripts/kvm/runtime_certification.sh
```

**Exports de VM : gestion personnelle.** Le propriétaire choisit lui-même
le moment d'un export manuel, son support et sa méthode. Le moteur Borg
ne copie ni les disques ni les métadonnées libvirt.

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
- accès Rocky Linux via SSH/SFTP.
