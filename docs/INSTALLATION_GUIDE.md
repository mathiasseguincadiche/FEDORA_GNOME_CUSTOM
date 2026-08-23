# Guide d'installation

## 1. Fedora 44 Workstation

Partir d'une installation native Fedora 44 Workstation. Le dépôt ne partitionne ni ne formate les SSD ; Btrfs Fedora par défaut et EXT4 sont acceptés à ce stade.

## 2. Cloner

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
chmod +x *.sh diagnostics/* scripts/*.sh scripts/systemd/* modules/*/*.sh
```

## 3. Diagnostic

```bash
./diagnostic.sh
```

## 4. Dry-run

```bash
./install.sh --dry-run
```

## 5. Backup pré-APPLY

Configurer `BACKUP_REPOSITORY` et `BACKUP_PASSWORD_FILE` dans `config/backup.conf`, puis :

```bash
./prepare-preapply-backup.sh
```

## 6. APPLY

```bash
./install.sh --apply
```

Après l'installation, se déconnecter/reconnecter si l'appartenance au groupe `libvirt` a changé puis relancer `./diagnostic.sh`.
