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

## Ubuntu DevOps ne démarre pas

```bash
virsh --connect qemu:///system dominfo ubuntu-devops
virsh --connect qemu:///system domblklist ubuntu-devops
virsh --connect qemu:///system dumpxml ubuntu-devops
journalctl -u virtqemud -b --no-pager 2>/dev/null || true
```

Vérifier le disque `/data/libvirt/images/ubuntu-devops.qcow2`, le seed cloud-init et le réseau `devops-nat`.

## Ubuntu inaccessible en SSH

```bash
virsh --connect qemu:///system domifaddr ubuntu-devops --source agent
virsh --connect qemu:///system net-dhcp-leases devops-nat
ssh -v mathias@192.168.50.x
```

SSH est key-only. Le mot de passe saisi à la création sert à la console et à `sudo`, pas à l'authentification SSH.

Dans le guest :

```bash
sudo systemctl status qemu-guest-agent
sudo /usr/local/sbin/devops-verify.sh
```

## Cloud-init / bootstrap Ubuntu incomplet

Dans le guest :

```bash
sudo cloud-init status --long
sudo cat /var/log/devops-bootstrap.log
sudo /usr/local/sbin/devops-verify.sh
```

Ne recréer la VM qu'après avoir conservé les données utiles et compris l'échec.

## Image Ubuntu refusée

La création exige l'image, `SHA256SUMS` et `SHA256SUMS.gpg` authentifiés.

```bash
bash scripts/kvm/verify_ubuntu_cloud_image.sh --help
```

Ne contourner ni la signature Canonical ni la comparaison SHA-256.

## Windows 11 : création refusée avant le disque

C'est normal si les hashes de confiance manquent. Les quatre entrées sont obligatoires :

```bash
bash scripts/kvm/create_windows11_vm.sh \
  --windows-iso /data/libvirt/iso/windows-11.iso \
  --virtio-iso /data/libvirt/iso/virtio-win.iso \
  --windows-sha256 '<sha256-windows-de-confiance>' \
  --virtio-sha256 '<sha256-virtio-de-confiance>'
```

Les deux SHA-256 doivent provenir de sources de confiance indépendantes. Un hash calculé uniquement après téléchargement ne prouve pas la provenance.

## Windows ne voit pas le disque ou le réseau

Monter `virtio-win.iso` dans l'installateur Windows et charger les pilotes VirtIO nécessaires. Après installation, ouvrir `FGC_TOOLS` puis lancer en PowerShell administrateur :

```text
Configure-GuestIntegration.ps1
```

Vérifier ensuite QEMU Guest Agent dans Windows et relancer :

```bash
bash scripts/kvm/runtime_certification.sh
```

## TPM / Secure Boot Windows en KO

```bash
virsh --connect qemu:///system dumpxml windows-11
```

Le profil attendu est Q35, UEFI Secure Boot avec clés enrôlées et TPM 2.0 `swtpm`. Ne remplacer pas ce profil par un BIOS legacy pour faire démarrer Windows.

## Accès fichiers Windows depuis Nautilus

Le partage SMB est facultatif et limité à `C:\VM-Share`. Après `Configure-GuestIntegration.ps1`, lancer `Configure-VMShare.ps1` uniquement si ce partage est souhaité.

Aucun partage invité/anonyme et aucun VirtioFS automatique n'appartiennent au contrat Golden.

## Sauvegarde VM refusée

Vérifier que les domaines sont réellement arrêtés :

```bash
virsh --connect qemu:///system list --all
```

Puis :

```bash
scripts/backup/backup-now.sh --include-vms
```

Le chemin attendu est : VM arrêtée → `qemu-img check` → conversion staging → Restic.

## Certification KVM échoue

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
bash scripts/kvm/runtime_certification.sh
```

Corriger le premier KO réel. La certification vérifie aussi l'isolation réseau et ne doit pas être forcée en modifiant les preuves.
