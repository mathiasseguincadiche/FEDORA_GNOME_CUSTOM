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
- runtime des timers installé dans un bundle immutable versionné par SHA et contrôlé par `MANIFEST.sha256` ;
- rétention Restic périodique versionnée : 7 daily / 4 weekly / 6 monthly sur les tags `full` et `daily`, groupée par `host,tags`.

## Pré-APPLY

Après un dry-run réussi sur le commit courant :

```bash
./prepare-preapply-backup.sh
```

Si `BACKUP_REPOSITORY` est vide, le helper recherche exactement **une** cible externe montée et utilise `Backup-Fedora/restic` dessus. Si plusieurs cibles externes sont montées, il bloque : renseigner alors `BACKUP_REPOSITORY` dans `config/local.conf`.

Le premier lancement peut créer le fichier de passphrase sous `~/.config/fedora-gnome-custom/secrets/restic-password`. La passphrase doit contenir au moins 16 caractères et le fichier est forcé en `0600`.

La capture contient notamment : inventaire RPM/Flatpak, services activés, stockage/montages, PCI/routage, fichiers suivis du projet, configuration GNOME utilisateur, archive privilégiée `/etc` + `/boot`, ainsi que les XML/domaines/réseaux/pools libvirt présents.

## Runtime backup autonome

Lors de l'APPLY, `modules/backup/60_daily_user_backup.sh` construit un bundle dédié sous :

```text
~/.local/lib/fedora-gnome-custom/backup-runtime/<SHA-appliqué>/
├── bin/
│   ├── daily-user-backup
│   └── restic-retention
├── lib/
│   ├── backup_runtime.sh
│   └── backup_runtime_bundle.sh
├── runtime/
│   ├── APPLIED_SHA
│   └── backup-runtime.conf
└── MANIFEST.sha256
```

`backup-runtime.conf` est un snapshot minimal des seules variables `BACKUP_*`, `RESTIC_*` et `DAILY_*`. La passphrase Restic n'y est jamais copiée : seul son chemin peut être enregistré. Le manifeste SHA-256 est vérifié au postcheck et à chaque exécution du runtime.

Un dossier nommé par SHA est **immutable** : un nouvel APPLY du même SHA réutilise le bundle uniquement si son `APPLIED_SHA` et son manifeste sont valides. Un dossier existant corrompu n'est jamais écrasé silencieusement ; l'APPLY échoue et demande une intervention explicite. Cela évite aussi de remplacer un runtime pendant qu'un timer l'utilise.

Les services systemd utilisateur pointent directement vers ce dossier SHA. Ils ne sourcent plus `bootstrap.sh`, `backup_runtime.sh` ou la configuration depuis le checkout Git. Déplacer, mettre à jour ou modifier le dépôt de travail ne change donc pas le comportement d'un timer déjà appliqué ; un nouvel APPLY est nécessaire pour installer un nouveau runtime.

Les états des timers sont enregistrés hors checkout sous :

```text
${XDG_STATE_HOME:-~/.local/state}/fedora-gnome-custom/
```

## Sauvegarde quotidienne utilisateur

Le timer quotidien résout les dossiers standards avec `xdg-user-dir` au moment de l'exécution. Les clés `DESKTOP`, `DOCUMENTS`, `PICTURES`, `VIDEOS` et `MUSIC` suivent donc la configuration XDG réelle de l'utilisateur : sur le profil français, `Bureau`, `Images`, `Vidéos` et `Musique` sont protégés sans dépendre de noms anglais codés en dur.

Les chemins supplémentaires restent `Projects`, `Development`, `.config`, `.ssh` et `.gnupg`. Un ancien override local `DAILY_BACKUP_PATHS` reste accepté comme fallback pour compatibilité.

Le script refuse une source XDG ambiguë qui résoudrait directement vers `$HOME`, refuse les chemins supplémentaires absolus ou contenant `..`, et enregistre le nombre ainsi que la liste exacte des sources incluses dans le snapshot.

L'indisponibilité temporaire du repository externe ou de la passphrase fait **skipper** le run quotidien sans désactiver le timer. Cela ne change pas le comportement fail-closed du backup pré-APPLY.

## Rétention périodique

La politique versionnée est :

```text
7 daily
4 weekly
6 monthly
```

Un timer systemd utilisateur dédié exécute par défaut la rétention chaque dimanche à 04:15, avec un délai aléatoire maximal de 30 minutes :

```text
fedora-gnome-restic-retention.timer
```

Il lance le runtime installé `restic-retention`, applique `restic forget` séparément aux tags `fedora-gnome-custom-full` et `fedora-gnome-custom-daily`, puis exécute **un seul** `restic prune`.

La commande `forget` utilise explicitement `--group-by host,tags`. Ce choix est essentiel : le backup complet contient un staging horodaté et Restic groupe sinon par `host,paths` par défaut ; laisser `paths` dans la clé de groupe pourrait fragmenter chaque backup complet en groupes distincts et empêcher la politique 7/4/6 de plafonner réellement les snapshots. Le contrat Golden regroupe donc par workstation et classe de snapshot, indépendamment du chemin de staging.

Si le disque/repository n'est pas disponible au créneau prévu, le run est enregistré comme `skipped` et le timer reste sain. `Persistent=true` permet à systemd de rejouer une échéance manquée après reconnexion/démarrage selon son comportement normal.

La rétention reste également déclenchable manuellement :

```bash
scripts/backup/backup-now.sh --prune
# ou
./control.sh backup prune
```

Le chemin manuel est strict : une cible Restic indisponible provoque un échec explicite au lieu d'un skip.

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

Pour créer le backup puis appliquer immédiatement la rétention :

```bash
scripts/backup/backup-now.sh --prune
# avec les disques VM arrêtés :
scripts/backup/backup-now.sh --include-vms --prune
```

## Diagnostic

```bash
diagnostics/backup-doctor
diagnostics/backup-doctor --deep
diagnostics/daily-backup-doctor
```

Le doctor quotidien vérifie notamment l'intégrité du bundle installé, l'activation des timers daily/rétention et les derniers états enregistrés. `backup-doctor --deep` ajoute un contrôle Restic partiel plus coûteux.

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
