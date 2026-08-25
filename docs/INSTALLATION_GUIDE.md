# Guide d'installation — Fedora 44 GNOME 50

## 1. Installer Fedora 44 Workstation

Utiliser Fedora 44 Workstation natif avec GNOME 50/Wayland. Le projet ne partitionne, ne formate et ne monte aucun SSD automatiquement.

Le SSD VM dédié doit être préparé manuellement en EXT4 et monté sur `/data` avant la convergence KVM.

## 2. Cloner et identifier la révision

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git checkout main
git pull --ff-only
chmod +x menu.sh diagnostic.sh install.sh prepare-preapply-backup.sh
cat VERSION
git rev-parse HEAD
```

## 3. Configuration locale

```bash
cp config/local.conf.example config/local.conf
$EDITOR config/local.conf
```

`config/local.conf` est ignoré par Git. Il sert notamment à approuver explicitement la machine réelle. Les secrets n'y sont pas nécessaires : `BACKUP_PASSWORD_FILE` ne contient que le chemin du fichier secret.

Pour le backup, deux modes sont possibles :

- laisser `BACKUP_REPOSITORY` vide : le helper sélectionne exactement une cible externe USB/hotplug montée ;
- définir explicitement un repository local externe ou Restic distant.

## 4. Diagnostic et baseline

```bash
./diagnostic.sh
bash diagnostics/baseline-doctor status
```

La baseline doit être certifiée pour le fingerprint matériel/BIOS courant avant l'APPLY.

## 5. Dry-run du commit courant

```bash
./install.sh --dry-run
```

Le succès écrit une preuve liée au SHA Git courant.

## 6. Backup pré-APPLY vérifié

```bash
./prepare-preapply-backup.sh
```

Le backup doit passer chiffrement, `restic check` et restauration du canary. Le marker est lui aussi lié au SHA Git courant : modifier le dépôt après le backup invalide volontairement l'APPLY.

## 7. APPLY réel

```bash
./install.sh --apply
```

Le gate exige : fonctionnalité APPLY activée, `REAL_MACHINE_APPROVED=true` uniquement dans `config/local.conf`, TTY interactif, Git propre, dry-run même commit, baseline valide, backup même commit et confirmation exacte.

## 8. Postchecks HOST

```bash
./diagnostic.sh
diagnostics/gnome-doctor
diagnostics/applications-doctor
diagnostics/media-doctor
diagnostics/virtualization-doctor
diagnostics/backup-doctor
```

Se déconnecter/reconnecter si l'appartenance aux groupes `libvirt`/`kvm` vient de changer.

## 9. Créer les VM

Ubuntu Server 26.04 :

```bash
scripts/kvm/create_ubuntu_devops_vm.sh --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Windows 11 :

```bash
scripts/kvm/create_windows11_vm.sh --windows-iso /data/libvirt/iso/windows-11.iso --virtio-iso /data/libvirt/iso/virtio-win.iso
```

## 10. Certification runtime

```bash
scripts/kvm/runtime_certification.sh
scripts/kvm/configure_nautilus_vm_access.sh refresh
```

Enfin, utiliser `menu.sh` pour les opérations courantes et `docs/BACKUP_RESTORE.md` pour le cycle backup/restore/DR.
