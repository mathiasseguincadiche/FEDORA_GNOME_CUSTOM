# Backup, Restore et Disaster Recovery

Le projet utilise **Borg 1.x avec un dépôt non chiffré** (décision du propriétaire, [ADR 0014](adr/0014-borg-unencrypted-backups.md)) et applique un modèle fail-closed. Une sauvegarde n'est pas considérée valide parce qu'une commande `backup` a simplement terminé : le dépôt exige une preuve d'intégrité et, pour le pré-APPLY et le backup complet, un test réel de restauration d'un canary.

## Contrat

- cible locale pré-APPLY obligatoirement prouvée externe (USB/removable/hotplug), ou dépôt Borg distant `ssh://` ;
- dépôt **non chiffré** : aucune passphrase n'existe ; un dépôt chiffré est refusé par la politique ;
- marker pré-APPLY lié au **même commit Git** que le dry-run et l'APPLY, et à l'archive exacte (nom + identifiant) ;
- `borg check --verify-data` sur l'archive pré-APPLY obligatoire (chaque bloc est relu et vérifié) ;
- restauration du canary obligatoire avant création de `state/preapply-backup.ok` ;
- aucune copie live d'un QCOW2 ;
- pour sauvegarder les disques VM, les domaines doivent être `shut off` ;
- aucune restauration automatique en place de `/`, `/etc`, `/boot`, `$HOME`, `/data` ou `/data/libvirt/images` ;
- runtime des timers installé dans un bundle immutable versionné par SHA et contrôlé par `MANIFEST.sha256` ;
- rétention Borg périodique versionnée : 7 daily / 4 weekly / 6 monthly, appliquée séparément aux archives `fgc-full-*` et `fgc-daily-*` ; les archives `fgc-preapply-*` (points de retour arrière) ne sont jamais supprimées automatiquement.

## Disque de sauvegarde de la machine cible

La fiche matérielle prévoit un troisième support de ~1,8 To, le **Kingston XS1000**, un **SSD externe USB 3.2 Gen 2** (et non un disque dur mécanique), en plus des deux T705. C'est la cible naturelle du dépôt Borg local, à condition de respecter le contrat du projet :

- il doit être **externe** (USB / amovible) : le projet refuse un dépôt sur le disque système ou sur `/data` ;
- il doit être formaté en **ext4** (`BACKUP_PREAPPLY_REQUIRED_FSTYPE`). Un XS1000 neuf est livré en exFAT : il faut le reformater une fois (cela **efface** son contenu) ;
- il doit être **seul** support externe monté lors du pré-APPLY, sinon la détection automatique s'arrête par sécurité. Dans ce cas, renseigner `BACKUP_REPOSITORY` dans `config/local.conf`.

**Le dépôt n'est pas chiffré** : toute personne qui possède le disque peut lire les sauvegardes, y compris `~/.ssh`, `~/.gnupg` et les profils de navigateur. Ranger le disque en conséquence. En contrepartie, aucune passphrase ne peut être perdue : un Fedora neuf avec `borgbackup` suffit pour restaurer.

## Deux niveaux de protection des données

Le second T705 monté sur `/data` fournit une première protection contre la perte ou la réinstallation du **SSD système Btrfs**. Il contient :

```text
/data/
├── Documents/
├── Projets/
├── ISO/
├── Jeux/
└── libvirt/
```

Ce disque n'est jamais formaté automatiquement par le projet. Une réinstallation du premier T705 doit donc remonter le même `/data` et conserver ces données.

Ce mécanisme n'est toutefois **pas un backup** contre la panne du second T705. Les données irremplaçables restent protégées par Borg sur une cible externe/off-machine : `/data/Documents` via XDG Documents et `/data/Projets` explicitement. `/data/ISO` et `/data/Jeux` sont exclus des backups automatiques par défaut car ces payloads sont généralement volumineux et reproductibles/retéléchargeables.

Les sauvegardes de jeux non reproductibles, mods rares ou autres contenus importants stockés directement sous `/data/Jeux` doivent donc être ajoutées par une politique opérateur explicite si nécessaire. Les sauvegardes de parties placées dans les chemins utilisateur/XDG restent couvertes normalement par Borg.

## Pré-APPLY

Après un dry-run réussi sur le commit courant :

```bash
./prepare-preapply-backup.sh
```

Si `BACKUP_REPOSITORY` est vide, le helper recherche exactement **une** cible externe montée et utilise `Backup-Fedora/borg` dessus. Si plusieurs cibles externes sont montées, il bloque : renseigner alors `BACKUP_REPOSITORY` dans `config/local.conf`.

Au premier lancement, le dépôt est créé avec `borg init --encryption=none` après une confirmation tapée à la main. L'archive `fgc-preapply-<date>` est ensuite écrite, relue intégralement (`borg check --verify-data`) puis un fichier témoin (*canary*) est réellement extrait et comparé.

La capture contient notamment : inventaire RPM/Flatpak, services activés, stockage/montages, PCI/routage, fichiers suivis du projet, configuration GNOME utilisateur, archive privilégiée `/etc` + `/boot`, ainsi que les XML/domaines/réseaux/pools libvirt présents.

## Runtime backup autonome

Lors de l'APPLY, `modules/backup/60_daily_user_backup.sh` construit un bundle dédié sous :

```text
~/.local/lib/fedora-gnome-custom/backup-runtime/<SHA-appliqué>-<SHA256-configuration>/
├── bin/
│   ├── daily-user-backup
│   └── backup-retention
├── lib/
│   ├── backup_runtime.sh
│   └── backup_runtime_bundle.sh
├── runtime/
│   ├── APPLIED_SHA
│   └── backup-runtime.conf
└── MANIFEST.sha256
```

`backup-runtime.conf` est un snapshot minimal des seules variables `BACKUP_*` et `DAILY_*`. Aucune variable `BORG_*` de l'environnement appelant n'y est copiée, et une `BORG_PASSPHRASE` ambiante est neutralisée à l'exécution. Le manifeste SHA-256 est vérifié au postcheck et à chaque exécution du runtime.

Un dossier nommé par SHA est **immutable** : un nouvel APPLY du même SHA réutilise le bundle uniquement si son `APPLIED_SHA` et son manifeste sont valides. Un dossier existant corrompu n'est jamais écrasé silencieusement ; l'APPLY échoue et demande une intervention explicite. Cela évite aussi de remplacer un runtime pendant qu'un timer l'utilise.

Les services systemd utilisateur pointent directement vers ce dossier SHA. Ils ne sourcent plus `bootstrap.sh`, `backup_runtime.sh` ou la configuration depuis le checkout Git. Déplacer, mettre à jour ou modifier le dépôt de travail ne change donc pas le comportement d'un timer déjà appliqué ; un nouvel APPLY est nécessaire pour installer un nouveau runtime.

Les états des timers sont enregistrés hors checkout sous :

```text
${XDG_STATE_HOME:-~/.local/state}/fedora-gnome-custom/
```

## Sauvegarde quotidienne utilisateur

Le timer quotidien résout les dossiers standards avec `xdg-user-dir` au moment de l'exécution. Les clés `DESKTOP`, `DOCUMENTS`, `PICTURES`, `VIDEOS` et `MUSIC` suivent donc la configuration XDG réelle de l'utilisateur. Dans le profil Golden, `DOCUMENTS` pointe vers `/data/Documents`; les autres dossiers restent résolus selon la locale utilisateur.

Le chemin supplémentaire persistant `/data/Projets` est sauvegardé avec `Development`, `.config`, `.ssh` et `.gnupg`. Un ancien override local `DAILY_BACKUP_PATHS` reste accepté comme fallback pour compatibilité.

La surface absolue autorisée est volontairement étroite : le script accepte `/data/Documents` et `/data/Projets`, mais refuse tout autre chemin absolu. `/data/ISO`, `/data/Jeux` et `/data/libvirt` ne peuvent donc pas être ajoutés accidentellement au backup quotidien par une dérive de configuration.

Le script refuse une source XDG ambiguë qui résoudrait directement vers `$HOME`, refuse les chemins contenant `..`, et enregistre le nombre ainsi que la liste exacte des sources incluses dans l'archive.

L'absence temporaire du disque externe (ou d'un dépôt distant) fait **skipper** le run quotidien sans désactiver le timer. Cela ne change pas le comportement fail-closed du backup pré-APPLY.

## Rétention périodique

La politique versionnée est :

```text
7 daily
4 weekly
6 monthly
```

Un timer systemd utilisateur dédié exécute par défaut la rétention chaque dimanche à 04:15, avec un délai aléatoire maximal de 30 minutes :

```text
fedora-gnome-backup-retention.timer
```

Il lance le runtime installé `backup-retention`, applique `borg prune` séparément aux archives `fgc-full-*` et `fgc-daily-*` (motif `--glob-archives`), puis exécute **un seul** `borg compact` pour libérer réellement l'espace.

Chaque classe d'archive a sa propre politique : un backup complet ne peut donc jamais « consommer » la place d'une archive quotidienne, et inversement. Les archives `fgc-preapply-*` ne correspondent à aucun motif de rétention.

Si le disque/repository n'est pas disponible au créneau prévu, le run est enregistré comme `skipped` et le timer reste sain. `Persistent=true` permet à systemd de rejouer une échéance manquée après reconnexion/démarrage selon son comportement normal.

La rétention reste également déclenchable manuellement :

```bash
scripts/backup/backup-now.sh --prune
# ou
./control.sh backup prune
```

Le chemin manuel est strict : une cible Borg indisponible provoque un échec explicite au lieu d'un skip.

## Backup d'exploitation

HOST + métadonnées KVM + Documents/Projets persistants :

```bash
scripts/backup/backup-now.sh
```

HOST + métadonnées + disques QCOW2 :

```bash
scripts/backup/backup-now.sh --include-vms
```

Cette deuxième commande **refuse** toute VM qui n'est pas arrêtée. Les images sont d'abord recopiées par `qemu-img convert` vers un staging cohérent, vérifiées avec `qemu-img check`, puis seulement archivées par Borg.

Pour créer le backup puis appliquer immédiatement la rétention :

```bash
scripts/backup/backup-now.sh --prune
# avec les disques VM arrêtés :
scripts/backup/backup-now.sh --include-vms --prune
```

## Diagnostic

```bash
diagnostics/data-storage-doctor
diagnostics/backup-doctor
diagnostics/backup-doctor --deep
diagnostics/daily-backup-doctor
```

`data-storage-doctor` vérifie que `/data` est bien l'EXT4 dédié, que `Documents`, `Projets`, `ISO` et `Jeux` existent avec le bon propriétaire, le mode `0750`, le label SELinux utilisateur et le mapping XDG Documents. Le doctor quotidien vérifie notamment l'intégrité du bundle installé, l'activation des timers daily/rétention et les derniers états enregistrés. `backup-doctor --deep` relit toutes les données du dépôt (`borg check --verify-data`), ce qui est plus long.

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
scripts/backup/restore.sh restore <archive> /chemin/staging/vide '/chemin/absolu/optionnel'
```

Le helper refuse les destinations sensibles/actives. On inspecte ensuite le staging avant toute restauration manuelle. Cette règle s'applique également à `/data` : le projet ne remplace jamais automatiquement les données persistantes existantes.

## Récupération après perte totale

Le dépôt n'étant pas chiffré, il n'y a **aucun secret à conserver** : sur une machine neuve, installer `borgbackup`, cloner le projet, brancher le disque et lancer `scripts/backup/restore.sh list` (ou directement `borg list <dépôt>`). La contrepartie est physique : le disque de sauvegarde doit être conservé comme un document sensible.

## Disaster Recovery

```bash
scripts/backup/disaster-recovery.sh
```

Ce générateur de plan exige `borgbackup`, `jq` et Python 3.

Le script sélectionne uniquement la dernière archive **full**, valide son manifeste de récupération, puis relit ses données (`borg check --verify-data`) puis génère dans `state/` un plan de reconstruction ordonné : Fedora 44, remontage du second T705 `/data` **sans formatage**, dépôt, dry-run, restauration staging, libvirt, QCOW2, labels SELinux et diagnostics finaux. Il est volontairement **non destructif**.

## Règle QCOW2

Ne jamais copier un disque QCOW2 actif avec `cp`, `rsync` ou Borg en espérant obtenir une sauvegarde cohérente. Ce projet choisit volontairement le contrat simple et robuste : **VM arrêtée → qemu-img check → qemu-img convert → Borg**.

## Qualification après l'audit de fiabilité

Un nouvel APPLY au même commit avec une autre configuration de sauvegarde crée
un nouveau bundle immuable. Le doctor compare aussi sa configuration avec celle
du dépôt. Les variables d'environnement `BORG_*` ne sont jamais sérialisées
dans ce bundle.

Les profils Firefox, données Flatpak et données applicatives utilisateur sont
inclus via `.mozilla`, `.var/app` et `.local/share`. Ces répertoires peuvent être
volumineux : dimensionner et vérifier le support externe. Le dossier
`~/.config/fedora-gnome-custom/secrets` reste exclu des archives.

`backup-now.sh --include-vms` exige toutes les VM arrêtées et inclut les disques
qcow2, les variables UEFI (NVRAM) et l'état swtpm, avec un inventaire JSON par VM.
Un disque ou backend TPM non pris en charge bloque la sauvegarde au lieu d'être
ignoré. Empêcher tout démarrage automatique ou manuel des VM pendant cette
opération. Une vérification de l'état avant/après ne constitue pas un verrou
contre un autre administrateur.

Pour un exercice réel, sélectionner un nom d'archive exact :

```bash
./scripts/backup/restore.sh list
./scripts/backup/restore.sh verify
./scripts/backup/restore.sh restore fgc-full-AAAAMMJJTHHMMSS... /chemin/vers/staging-vide
```

`verify` relit toutes les données du dépôt (`borg check --verify-data`) ; Borg
vérifie aussi chaque bloc contre son empreinte pendant l'extraction. Comparer ensuite les documents,
permissions et liens attendus. Une restauration de fichiers réussie ne prouve
pas le redémarrage de Fedora ou de Windows.

Pour les VM : inspecter le plan JSON, extraire l'archive d'état persistant dans
un second staging, puis remettre disque, NVRAM et swtpm ensemble, VM arrêtée,
avec son UUID d'origine et les bons propriétaires/labels SELinux. Démarrer une
copie de récupération isolée du réseau et de la VM originale. Vérifier Windows,
le TPM et l'accès aux données avant de déclarer la reprise opérationnelle.

Le test `tests/test_borg_roundtrip.sh` exerce un vrai dépôt Borg non chiffré,
le runtime quotidien installé, la rétention et le script de restauration. Il
vérifie contenu, permissions, lien symbolique, exclusion du dossier secrets,
refus d'écraser un staging existant, refus d'un nom d'archive malformé, preuve
pré-APPLY exacte (nom, identifiant, type) et refus d'un dépôt chiffré. Son disque externe est simulé : ce test n'émet aucune preuve Gate 3.

## Certification et capacité depuis 0.19

Seul un code de création Borg **0** permet d'enregistrer un succès. Un code 1
peut correspondre à des fichiers illisibles/omis ; la tentative échoue même si
Borg a écrit une archive. Le timer conserve un état d'échec, détecté par le
doctor quotidien. Un disque absent reste un état `skipped`, distinct du succès.

Le backup complet restaure et compare un canary, puis écrit atomiquement un
marker contenant dépôt, nom/id, commit, empreintes configuration/plan/matériel,
contrôle d'intégrité, restauration et couverture VM. Le doctor de certification
réouvre cette **archive exacte**, contrôle son manifeste et extrait son canary.
Une archive supprimée, un dépôt différent ou une configuration modifiée invalide
la preuve. Les anciens markers complets doivent être régénérés.

Le manifeste de récupération est inclus dans le staging et dans le commentaire
Borg de l'archive complète. Le plan précise le commit à récupérer et si les
disques VM ont été inclus, avec le nombre de domaines. Sans `--include-vms`,
les XML seuls ne prouvent jamais une récupération VM. Une archive quotidienne,
même plus récente, reste réservée à la récupération des fichiers utilisateur.

Le staging par défaut reste sous `state/backup-staging`. Pour choisir un autre
espace de travail :

```bash
scripts/backup/backup-now.sh --include-vms --staging-root /chemin/absolu/backup-staging
```

Avant la capture système et chaque copie VM, l'espace disponible doit couvrir
la taille estimée et conserver 1 Gio de réserve. Les disques VM sont dimensionnés
avec `qemu-img measure`. Avant l'archivage local, la taille des sources et la
réserve configurée (20 Gio par défaut) doivent tenir sur le support externe.
Cette estimation est conservatrice : compression et déduplication ne permettent
pas de contourner le contrôle. La capacité d'un dépôt distant ne peut pas être
mesurée localement ; une erreur Borg y reste bloquante.

La qualification réelle suit [le parcours de fiabilité](RELIABILITY_QUALIFICATION.md).
Aucun conteneur ne certifie le démarrage Fedora, la session GNOME, le TPM d'une VM
récupérée ou le matériel physique.

Les créations commencent dans le namespace `fgc-pending-<type>-*`. Pour
`fgc-preapply-*` et `fgc-full-*`, seul un code de création 0 permet la
promotion, avec relecture de l'identifiant après renommage. Pour la sauvegarde
**quotidienne**, qui tourne pendant la session, un seul avertissement est toléré :
« file changed while we backed it up » (profil de navigateur, données Flatpak
modifiées pendant la lecture). L'archive est complète et contient la version
lue ; le nombre de fichiers concernés est enregistré dans le marker
(`files_changed_during_backup`) et affiché par `daily-backup-doctor`. Tout autre
avertissement (fichier illisible, source absente…) refuse l'archive.

Une archive refusée reste inspectable dans `fgc-pending-*` et ne peut devenir
automatiquement une base de récupération. La rétention hebdomadaire n'en garde
que les plus récentes (`BACKUP_KEEP_PENDING`, 3 par défaut) pour qu'elles ne
remplissent jamais le disque, et les diagnostics signalent leur présence.

Pour Gate 3, la politique `BACKUP_VM_DISKS=true` avec KVM actif impose un backup
`--include-vms`. La certification compare le nombre et l'empreinte de la liste
triée des domaines sauvegardés avec la liste actuelle de libvirt, accessible
avec les droits sudo déjà disponibles. Une sauvegarde de métadonnées seule ou
une liste de VM modifiée bloque la certification ; la commande de backup HOST
sans disques VM reste disponible pour les sauvegardes intermédiaires.
