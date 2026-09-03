# Backup, Restore et Disaster Recovery

Le projet utilise **Restic chiffré** et applique un modèle fail-closed. Une sauvegarde n'est pas considérée valide parce qu'une commande `backup` a simplement terminé : le dépôt exige une preuve d'intégrité et, pour le pré-APPLY, un test réel de restauration d'un canary.

## Contrat

- cible locale pré-APPLY obligatoirement prouvée externe (USB/removable/hotplug), ou repository Restic distant ;
- pas de secret dans Git ;
- mot de passe Restic dans un fichier `0600` hors dépôt ;
- marker pré-APPLY lié au **même commit Git** que le dry-run et l'APPLY ;
- `restic check --read-data-subset` obligatoire ;
- restauration du canary obligatoire avant création de `state/preapply-backup.ok` ;
- aucune copie live d'un QCOW2 ;
- pour sauvegarder les disques VM, les domaines doivent être `shut off` ;
- aucune restauration automatique en place de `/`, `/etc`, `/boot`, `$HOME` ou `/data/libvirt/images` ;
- pruning Restic explicite uniquement.

## Pré-APPLY

Après un dry-run réussi sur le commit courant :

```bash
./prepare-preapply-backup.sh
```

Si `BACKUP_REPOSITORY` est vide, le helper recherche exactement **une** cible externe montée et utilise `Backup-Fedora/restic` dessus. Si plusieurs cibles externes sont montées, il bloque : renseigner alors `BACKUP_REPOSITORY` dans `config/local.conf`.

Le premier lancement peut créer le fichier de passphrase sous `~/.config/fedora-gnome-custom/secrets/restic-password`. La passphrase doit contenir au moins 16 caractères et le fichier est forcé en `0600`.

La capture contient notamment : inventaire RPM/Flatpak, services activés, stockage/montages, PCI/routage, fichiers suivis du projet, configuration GNOME utilisateur, archive privilégiée `/etc` + `/boot`, ainsi que les XML/domaines/réseaux/pools libvirt présents.

## Sauvegarde quotidienne utilisateur

Le timer quotidien résout les dossiers standards avec `xdg-user-dir` au moment de l'exécution. Les clés `DESKTOP`, `DOCUMENTS`, `PICTURES`, `VIDEOS` et `MUSIC` suivent donc la configuration XDG réelle de l'utilisateur : sur le profil français, `Bureau`, `Images`, `Vidéos` et `Musique` sont protégés sans dépendre de noms anglais codés en dur.

Les chemins supplémentaires restent `Projects`, `Development`, `.config`, `.ssh` et `.gnupg`. Un ancien override local `DAILY_BACKUP_PATHS` reste accepté comme fallback pour compatibilité.

Le timer est lié au **SHA appliqué** : si le checkout versionné change ou si ses fichiers suivis sont modifiés sans nouvel APPLY, le backup automatique bloque au lieu de sourcer silencieusement un runtime différent.

Le script refuse une source XDG ambiguë qui résoudrait directement vers `$HOME`, refuse les chemins supplémentaires absolus ou contenant `..`, et enregistre dans `state/last-daily-backup.ok` le nombre ainsi que la liste exacte des sources incluses dans le snapshot.

## Backup d'exploitation

HOST + métadonnées KVM :

```bash
scripts/backup/backup-now.sh
```

HOST + métadonnées + disques QCOW2 :

```bash
scripts/backup/backup-now.sh --include-vms
```

Cette deuxième commande **refuse** toute VM qui n'est pas arrêtée. Les images sont d'abord recopiées par `qemu-img convert` vers un staging cohérent, vérifiées avec `qemu-img check`, puis seulement envoyées à Restic.

Pour appliquer **manuellement** la rétention 7 daily / 4 weekly / 6 monthly aux snapshots `full` **et** `daily` :

```bash
scripts/backup/backup-now.sh --prune
# ou, pour inclure aussi les disques VM arrêtés :
scripts/backup/backup-now.sh --include-vms --prune
```

Le pruning n'est jamais lancé automatiquement par la convergence ni par le timer quotidien. `--prune` applique les deux politiques `forget` (`full` puis `daily`) puis exécute un unique `restic prune`.

## Diagnostic

```bash
diagnostics/backup-doctor
diagnostics/backup-doctor --deep
```

`--deep` ajoute un contrôle Restic partiel plus coûteux.

## Restauration staging-first

Lister :

```bash
scripts/backup/restore.sh list
```

Vérifier :

```bash
scripts/backup/restore.sh verify
```

Restaurer sans toucher au système live :

```bash
scripts/backup/restore.sh restore latest
```

ou :

```bash
scripts/backup/restore.sh restore <snapshot> /chemin/staging/vide '<glob-optionnel>'
```

Le helper refuse les destinations sensibles/actives. On inspecte ensuite le staging avant toute restauration manuelle.

## Secret de récupération

La passphrase Restic n'est volontairement jamais incluse dans les snapshots. Une **copie de récupération hors machine** (gestionnaire de mots de passe ou coffre indépendant) est donc obligatoire pour qu'un dépôt Restic reste exploitable après perte totale du SSD système. Le projet ne copie jamais ce secret automatiquement.

## Disaster Recovery

```bash
scripts/backup/disaster-recovery.sh
```

Le script vérifie le repository et le dernier snapshot puis génère dans `state/` un plan de reconstruction ordonné : Fedora 44, `/data`, dépôt, dry-run, restauration staging, libvirt, QCOW2, labels SELinux et diagnostics finaux. Il est volontairement **non destructif**.

## Règle QCOW2

Ne jamais copier un disque QCOW2 actif avec `cp`, `rsync` ou Restic en espérant obtenir une sauvegarde cohérente. Ce projet choisit volontairement le contrat simple et robuste : **VM arrêtée → qemu-img check → qemu-img convert → Restic**.
