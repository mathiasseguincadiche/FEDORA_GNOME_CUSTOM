# Guide d'installation

## 1. Fedora 44 Workstation

Partir d'une installation native Fedora 44 Workstation. Le dépôt ne partitionne ni ne formate les SSD ; Btrfs Fedora par défaut et EXT4 sont acceptés à ce stade.

## 2. Cloner

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
chmod +x *.sh diagnostics/* scripts/*.sh scripts/systemd/* modules/*/*.sh
```

## 3. Configuration locale non versionnée

```bash
cp config/local.conf.example config/local.conf
$EDITOR config/local.conf
```

`config/local.conf` est ignoré par Git. Il permet d'approuver explicitement la machine réelle et de définir le repository Restic sans rendre le working tree sale. Ne stockez jamais le mot de passe Restic dans Git ; configurez seulement `BACKUP_PASSWORD_FILE`.

## 4. Diagnostic

```bash
./diagnostic.sh
```

## 5. Dry-run

```bash
./install.sh --dry-run
```

## 6. Backup pré-APPLY

```bash
./prepare-preapply-backup.sh
```

Le script installe uniquement `restic`/`jq` si nécessaire, initialise exclusivement le repository explicitement configuré, réalise le snapshot et vérifie son intégrité avant d'écrire le marker de sécurité.

## 7. APPLY

```bash
./install.sh --apply
```

Après l'installation, se déconnecter/reconnecter si l'appartenance au groupe `libvirt` a changé puis relancer `./diagnostic.sh`.
