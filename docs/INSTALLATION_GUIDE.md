# Guide d'installation neuve — Fedora 45 Workstation / GNOME 51

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — préconditions de l'APPLY et verrouillage des overrides relus contre `lib/apply_gate.sh` et le schéma de configuration — matériel : non vérifié

Installer une workstation ne se résume pas à lancer un script. Avant chaque modification, ce projet demande de **vérifier le point de départ**, **prévoir un retour arrière** et **conserver une preuve du résultat**.

Ce guide accompagne l'opérateur sur le **PC physique cible** : image Fedora authentifiée, essai Live USB, décision humaine, installation sur le bon SSD, configuration protégée, puis qualification finale. Il est la référence pour **l'ordre réel des opérations**. Le guide de [qualification](QUALIFICATION.md) détaille, lui, **les critères des preuves**.

**Résultat recherché :** Fedora 45 fonctionne avec la configuration appliquée, les données restent séparées du système et la Gate 3 a réellement qualifié le poste installé. Le statut « Golden runtime-certified » ne peut pas être déduit d'une simple CI verte.

> [!NOTE]
> **Ce qui a été essayé :** la CI teste certains mécanismes dans des VM jetables (média, dry-run, Borg, session GNOME). **Ce qui reste à éprouver :** le parcours complet sur la machine physique. Voir l'[état réel](../README.md#état-réel) et la [fiche de qualification physique](PHYSICAL_QUALIFICATION_CHECKLIST.md).

Pour comprendre pourquoi les contrôles peuvent interdire l'APPLY, lire d'abord les [notions clés](CONCEPTS.md). Les procédures ci-dessous sont destinées à être suivies dans l'ordre ; elles ne constituent pas un catalogue de commandes indépendantes.

## Résumé d'exécution

Cette liste sert de **journal de progression** si l'installation est interrompue. Relire d'abord la [règle d'arrêt](#règle-darrêt), puis reprendre à la première case non cochée en consultant la section complète :

- [ ] Média Fedora 45 authentifié (section 1)
- [ ] Contrôle Live `GO`, compte rendu exporté puis examiné (section 2)
- [ ] **GO humain explicite** avant toute installation sur SSD (section 2)
- [ ] Fedora installée sur le T705 système, preuve importée au même commit (section 2)
- [ ] Outils et `config/local.conf` prêts, second T705 monté sur `/data` (sections 3 et 4)
- [ ] Baseline certifiée, dry-run final, sauvegarde pré-APPLY vérifiée (sections 5 à 7)
- [ ] APPLY terminé, redémarrage sur Linux amont N (sections 8 et 9)
- [ ] Premier login GNOME contrôlé (section 10)
- [ ] Gate 3 `PASS`, état certifié vérifié (sections 11 et 12)

Ce résumé ne remplace ni les prérequis ni les validations : il rend l'état d'une exécution visible sans relire le guide. **Si un APPLY a déjà commencé puis échoué, ne pas simplement reprendre à la case non cochée** : suivre d'abord le [diagnostic d'un APPLY partiel](TROUBLESHOOTING.md#installation-et-apply).

## Avant de commencer

### Préconditions

Avant toute modification du PC, réunir :

- le matériel cible, décrit dans l'[architecture](ARCHITECTURE.md#le-matériel-cible) ;
- l'ISO Fedora 45 Workstation finale et son CHECKSUM signé ;
- le dépôt sur un commit audité, dont la CI est verte ;
- le numéro de série de chacun des deux T705 : l'un recevra le système, l'autre `/data` ;
- un support Borg externe en ext4, non chiffré, pour la sauvegarde pré-APPLY ;
- un second support externe, accessible en écriture, pour la preuve Live ;
- Secure Boot désactivé dans l'UEFI.

Le profil Fedora 45 est `ready` : son média et ses composants sont promus ([fiche Fedora 45](FEDORA45_PRIMARY.md)). Cette promotion ne remplace aucun des contrôles ci-dessous.

### Le parcours

| Phase | Sections | Résultat attendu |
| --- | --- | --- |
| Préinstaller | 1 et 2 | Média authentifié, observations Live `GO`, preuve exportée **et accord humain** |
| Installer Fedora | 2 | Fedora sur le T705 système, preuve Live importée au même commit |
| Préparer la configuration | 3 à 5 | Outils, `config/local.conf`, `/data` et baseline certifiée |
| Appliquer | 6 à 9 | Dry-run final, sauvegarde vérifiée, APPLY, redémarrage sur Linux amont N |
| Qualifier | 10 à 12 | Premier login, Gate 3 PASS, état certifié vérifié |

L'exploitation courante (mises à jour, sauvegardes quotidiennes, récupération) est décrite [après ce guide](#après-la-certification).

### Règle d'arrêt

Le parcours échoue fermé : **ne pas continuer** quand une précondition, un doctor ou un contrôle échoue. Corriger la cause, puis relancer le contrôle concerné. En particulier, l'APPLY est hors de question si :

- le média n'est pas authentifié ou le profil n'est pas `ready` ;
- `/data` ne désigne pas, sans ambiguïté, le second T705 ;
- la baseline n'est pas certifiée, ou le dry-run est périmé ;
- la sauvegarde pré-APPLY n'est plus vérifiable ;
- Secure Boot est actif ou indéterminé ;
- le dépôt Git contient des modifications.

La section [En cas d'échec](#en-cas-déchec) liste les refus les plus probables et leur correction.

### Points de non-retour

> [!CAUTION]
> Trois étapes changent l'état du PC d'une façon qu'un simple retour en arrière ne défait pas. Avant chacune, confirmer ce qui est indiqué :

| Étape | Ce qui devient irréversible | À confirmer avant |
| --- | --- | --- |
| Section 2, confirmation de l'installateur Fedora (ou phrase du Kickstart) | le T705 choisi est effacé | numéro de série du disque relu ; preuve Live exportée hors des deux T705 |
| Section 4, formatage d'un second T705 **neuf** | tout contenu de ce disque est perdu | numéro de série ; le disque ne contient aucune donnée à garder |
| Section 8, `./install.sh --apply` | le système converge vers le dépôt ; revenir en arrière demande une restauration manuelle | sauvegarde pré-APPLY vérifiée et support branché |

---

## 1. Vérifier le média Fedora 45

**But :** prouver que l'ISO à écrire sur la clé USB est bien le média final promu, signé par Fedora.

**Où :** une machine Linux disposant du dépôt, de `gpg` (pour convertir la clé), de `gpgv` (pour vérifier la signature), de `python3` et de `sha256sum`, avant d'écrire la clé. Les deux commandes GnuPG ont des rôles distincts : posséder `gpgv` seul ne suffit pas à exécuter l'exemple ci-dessous.

Le verrou `installer/fedora45-media.lock` fixe le média attendu : `Fedora-Workstation-Live-45-1.4.x86_64.iso`, SHA-256 `68338c6bfe4f0d64151f2e47efe9f44a8855ad05b460e56b844fb3fa2c9a3beb`. Le vérificateur demande un trousseau contenant la clé Fedora 45. Sur une Fedora, il se prépare à partir du paquet `fedora-gpg-keys` ; ailleurs, la clé publique est sur la [page sécurité de Fedora](https://fedoraproject.org/security/).

Depuis la racine du dépôt, préparer un trousseau **temporaire hors du clone**. Le chemin de la clé ci-dessous est celui du paquet Fedora ; sur une autre distribution, importer uniquement la clé obtenue depuis la source officielle et en vérifier l'empreinte.

```bash
# Préparation locale : ce répertoire temporaire ne sera jamais suivi par Git.
MEDIA_KEY_DIR="$(mktemp -d)"
gpg --dearmor -o "$MEDIA_KEY_DIR/fedora45.gpg" \
  /usr/share/pki/rpm-gpg/RPM-GPG-KEY-fedora-45-primary

installer/verify-fedora-media.sh --release 45 \
  --iso /chemin/Fedora-Workstation-Live-45-1.4.x86_64.iso \
  --checksum /chemin/Fedora-Workstation-45-1.4-x86_64-CHECKSUM \
  --keyring "$MEDIA_KEY_DIR/fedora45.gpg"
```

Après avoir **constaté et noté le résultat**, nettoyer uniquement les éléments créés pour ce contrôle (et uniquement si `MEDIA_KEY_DIR` contient toujours le chemin retourné par `mktemp`) :

```bash
rm -- "$MEDIA_KEY_DIR/fedora45.gpg"
rmdir -- "$MEDIA_KEY_DIR"  # refuse de supprimer un répertoire non vide
```

Le fichier de clé publique ne constitue pas une preuve à conserver ; préserver plutôt le journal du vérificateur et le SHA du commit.

Le vérificateur contrôle le nom des deux fichiers, le SHA-256 de l'ISO, la signature du CHECKSUM, l'empreinte de la clé qui l'a signé (`4F50A611…F577861E`, épinglée dans le verrou) et la ligne qui lie l'ISO à son hash. Il ne modifie rien.

**Réussite :** la sortie se termine par `Fedora 45 media PASS: Fedora-Workstation-Live-45-1.4.x86_64.iso`. Toute autre sortie arrête le parcours : ne pas écrire cette ISO sur la clé.

## 2. Contrôler le PC en Live, puis installer Fedora

### Observer le PC depuis « Try Fedora »

Démarrer la clé, choisir **Try Fedora** et ne pas lancer l'installateur. Le [contrôle Live](FEDORA45_LIVE_PREFLIGHT.md) fait foi pour cette étape : préparation du dépôt au commit audité, 16 points observés, réponses attendues et décision. En résumé :

```bash
git rev-parse HEAD                  # doit afficher le commit audité
./control.sh validate live plan     # affiche les 16 points, sans rien exécuter
./control.sh validate live run      # observations et questions
./control.sh validate export live /chemin/du/support-externe/preinstallation
```

**Réussite :** décision `GO` (les six points requis en `PASS`, aucun point en `FAIL`), puis le JSON et son fichier SHA-256 présents sur le support externe. Le HOME du Live disparaît au redémarrage : exporter avant de quitter. Ne pas utiliser l'un des deux T705 comme support de transfert.

> [!IMPORTANT]
> **Arrêt obligatoire avant l'installation.** Un `GO` calculé par le script n'est pas une autorisation de formater le SSD. Relire le compte rendu, les éventuels points `NOT_TESTED` et les symptômes observés, puis obtenir une décision explicite du propriétaire du PC. Le [guide Live USB, section « Décider avant toute installation »](FEDORA45_LIVE_PREFLIGHT.md#6-décider-avant-toute-installation) détaille ce passage de relais. Si l'accord manque, **ne pas continuer**.

### Installer Fedora sur le T705 système

Lancer l'installateur depuis la session Live.

Avant d'ouvrir l'installateur, retrouver dans l'[inventaire privé enregistré depuis le Live](FEDORA45_LIVE_PREFLIGHT.md#5-exporter-avant-le-redémarrage) les **deux numéros de série** et le rôle prévu pour chacun. Dans **la même session Live**, vérifier la correspondance avec les périphériques effectivement présents :

```bash
# Lecture seule : les deux T705 ont le même modèle, pas le même numéro de série.
lsblk -e7 -o NAME,TYPE,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

Cette correspondance aide à interpréter les disques montrés par l'installateur **dans cette session** ; un nom `/dev/nvme…` n'est jamais une identité permanente. Si l'interface graphique ne permet pas d'associer **sans ambiguïté** le disque choisi à la série du T705 système, **quitter l'installateur sans confirmer l'effacement** et demander une vérification complémentaire. Ne pas choisir par ordre ou par modèle identique.

1. Confirmer que le T705 système sélectionné correspond au **numéro de série approuvé**, et que le second T705 `/data` n'est pas sélectionné pour l'effacement.
2. Choisir une installation Btrfs, sans LUKS, conformément à l'[ADR 0002](adr/0002-no-secureboot-no-local-luks.md).
3. Ne pas toucher au second T705, réservé à `/data` : le dépôt ne le partitionne ni ne le formate jamais.
4. Relire le récapitulatif des changements de stockage **et la cible physique** avant de confirmer. En cas de doute, s'arrêter.

L'installation graphique ne lance pas `install.sh` : la configuration du projet commence au premier démarrage. Pour une installation automatisée, voir l'[option Kickstart](#option-avancée--kickstart).

### Premier démarrage sur le SSD

Retirer la clé, démarrer sur le T705 système et ouvrir la session GNOME. Installer Git s'il manque (`sudo dnf install git`), puis reprendre **le même commit** que celui du Live et importer la preuve :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git switch --detach SHA_DU_COMMIT_AUDITE
./control.sh validate import /chemin/du/support-externe/preinstallation/live-SHA_DU_COMMIT_AUDITE.json
./control.sh validate status
```

L'import vérifie le commit, le plan de modules et les identités physiques du PC ; il ne compare pas le noyau du Live à celui du système installé.

**Réussite :** `validate status` montre la preuve Live importée pour ce PC et ce commit. Une preuve d'un autre commit ou d'un autre PC est refusée : refaire alors le contrôle Live au bon commit.

## 3. Préparer les outils et la configuration locale

**But :** installer les outils de mesure et écrire les choix propres au PC, sans encore autoriser l'APPLY.

```bash
./control.sh install prepare-tools
```

Cette commande installe les paquets de `manifests/packages-baseline.txt`, dont `smartmontools`, sans rien mesurer ni certifier. Créer ensuite `config/local.conf`, fichier local non versionné, à partir de l'exemple :

```bash
test -e config/local.conf || cp config/local.conf.example config/local.conf
"${EDITOR:-nano}" config/local.conf
```

Dans ce fichier :

- garder `HOST_RELEASE="45"` ;
- garder `REAL_MACHINE_APPROVED="false"` jusqu'à la section 6 ;
- renseigner `BACKUP_REPOSITORY`, le chemin du dépôt Borg sur le support externe (l'exemple propose `/run/media/$USER/XS1000/Backup-Fedora/borg`).

La configuration effective comprend les fichiers versionnés **et** `config/local.conf` : toute retouche ultérieure périme le dry-run.

## 4. Préparer le second T705 pour `/data`

**But :** monter le second T705 sur `/data` et l'enregistrer comme disque de données, sans jamais le formater par le projet.

Ce disque conserve les documents, projets, ISO, jeux et disques de VM lors d'une réinstallation du système. **S'il contient déjà des données, ne pas le reformater.** S'il est neuf, la création d'un système de fichiers est une opération manuelle et destructive, distincte de l'APPLY. Les étapes vérifiables pour **les deux situations** sont décrites dans la [procédure dédiée au stockage `/data`](DATA_DISK_PREPARATION.md). La suivre **jusqu'à l'enrôlement de la section 3 compris**, puis revenir ici pour les contrôles de lecture :

```bash
findmnt /data                                            # lecture seule
./diagnostics/baseline-doctor storage-identity           # lecture seule : modèles, séries, montages
lsblk -f                                                 # lecture seule
```

**Ne pas réexécuter `enroll-data` ici** : cette opération d'écriture n'a qu'un seul point d'entrée documentaire, la [section 3 de la procédure `/data`](DATA_DISK_PREPARATION.md#3-enrôler-le-disque-et-reprendre-linstallation). Elle enregistre modèles, séries, WWN et UUID. Un changement de disque ou de montage invalide ensuite la baseline et bloque les écritures sur `/data` jusqu'à nouvelle qualification explicite.

L'APPLY créera ou normalisera cette arborescence, **sans supprimer de contenu** :

```text
/data/
├── Documents/      # documents ; le dossier XDG Documents pointe ici
├── Projets/        # projets de travail
├── ISO/            # images ISO, hors sauvegarde automatique
├── Jeux/           # bibliothèque de jeux, hors sauvegarde automatique
├── IA/Openclaw/    # projets IA, sauvegardés par Borg
└── libvirt/        # disques et fichiers des VM, hors Borg
```

**Réussite :** `findmnt` et `lsblk` montrent `/` et `/data` sur deux T705 physiques distincts, et `enroll-data` réussit.

## 5. Certifier la baseline matérielle

**But :** démontrer que le matériel réel correspond au profil avant toute modification. Les critères de chaque essai figurent dans la [qualification](QUALIFICATION.md#3-baseline-matérielle-avant-apply).

Enrôler d'abord les identités, puis tester la mémoire au profil 5600 MT/s :

```bash
./diagnostics/baseline-doctor enroll-wifi
./diagnostics/baseline-doctor enroll-bluetooth
./diagnostics/baseline-doctor list-cooling
# Identifier physiquement la pompe, le ventilateur CPU et le ventilateur boîtier.
./diagnostics/baseline-doctor enroll-cooling fanN fanM fanP
./diagnostics/baseline-doctor snapshot
./diagnostics/baseline-doctor run-memory-test 5600
```

Régler ensuite 6000 MT/s dans l'UEFI, redémarrer, puis terminer :

```bash
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-cpu-soak
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

Les essais mémoire et CPU durent environ deux heures et demie, d'après les durées par défaut de `diagnostics/baseline-doctor` : 3 600 secondes par passe mémoire (5600 puis 6000 MT/s) et 1 800 secondes de charge CPU. C'est une estimation à partir de ces durées, à laquelle s'ajoutent les essais NVMe. Le projet ne change jamais les réglages de l'UEFI ; chaque essai vérifie la vitesse réellement configurée. Les essais NVMe écrivent un fichier temporaire, jamais sur le disque brut.

**Réussite :** `certify` réussit. Le profil d'écran certifié est alors enregistré dans `~/.local/state/fedora-gnome-custom/display-profile.env`. Un échec matériel arrête le parcours.

## 6. Lancer le dry-run final

**But :** exécuter le plan **sans appliquer de modifications à la configuration cible**, et produire une preuve liée à l'état exact qui sera appliqué. Le dry-run **écrit des journaux et une preuve locale** ; ce n'est pas une commande sans aucune écriture.

Fixer d'abord la configuration définitive dans `config/local.conf` :

```text
HOST_RELEASE="45"
REAL_MACHINE_APPROVED="true"
```

Ce drapeau confirme que ce PC est la machine réelle ; il ne contourne aucun verrou. Lancer ensuite :

Les exigences de dépôt Git propre, de dry-run au même état, de baseline certifiée et de sauvegarde pré-APPLY restent **obligatoires**. Le validateur refuse de les désactiver dans `config/local.conf` (`REQUIRE_CLEAN_GIT`, `REQUIRE_SAME_COMMIT_DRYRUN`, `REQUIRE_HARDWARE_BASELINE_CERTIFIED`, `REQUIRE_PREAPPLY_BACKUP`). Si l'une manque, corriger la cause puis refaire les contrôles ; ne pas essayer de la contourner.

```bash
./install.sh --dry-run
```

Le dry-run exécute precheck, plan, apply et postcheck avec toutes les mutations neutralisées. Sa preuve est liée au commit, à la configuration effective, au plan de modules et à l'empreinte matérielle.

**Réussite :** le dry-run se termine sans module en échec. Toute modification ultérieure du commit, de `config/local.conf` ou du matériel impose de le relancer, puis de refaire la sauvegarde.

## 7. Créer la sauvegarde pré-APPLY

**But :** disposer d'une sauvegarde Borg dont l'intégrité est contrôlée et dont **une restauration de vérification** a réussi avant l'APPLY. Cela ne certifie pas à lui seul le retour complet d'un PC physique à son état précédent.

```bash
./prepare-preapply-backup.sh
```

Le script exige un dépôt Git propre et le dry-run du même état. Si Borg ou l'un de ses outils manque, il l'installe d'abord avec `sudo dnf` **(modification de paquets, avant la capture de la sauvegarde)**. Cette installation de dépendances est **distincte de l'APPLY** ; elle est prévue dans le comportement du script et ne constitue pas une simple lecture. Si le dépôt Borg n'existe pas encore sur le support, le script demande la phrase de confirmation définie dans `config/backup.conf` avant de le créer, sans chiffrement ([ADR 0014](adr/0014-borg-unencrypted-backups.md)). Il enchaîne ensuite :

```text
cible externe prouvée (ext4, 20 Gio libres au minimum)
  → archive Borg fgc-preapply-…
  → borg check --verify-data
  → restauration d'un fichier canari
  → contrôle de restauration de config/local.conf, s'il est présent dans l'inventaire
  → marqueur lié au même état que le dry-run
```

**Réussite :** le script se termine en confirmant le marqueur. Le canari et le contrôle de `local.conf` prouvent des **extractions ciblées**, pas une restauration complète de Fedora. Au moment de l'APPLY, le projet rouvre réellement le dépôt Borg et vérifie que l'archive exacte existe toujours : le marqueur seul ne suffit pas. Garder le support externe branché.

**Durée de validité :** le marqueur `state/preapply-backup.ok` reste recevable pendant **24 heures par défaut** après sa création (`BACKUP_MAX_AGE_HOURS` dans `config/backup.conf`). Passé ce délai, l'APPLY refuse de démarrer, même si l'archive Borg existe toujours : avant un premier APPLY, refaire la sauvegarde vérifiée sous l'état courant, après le dry-run requis. **Si un APPLY a déjà partiellement modifié le système, conserver d'abord l'archive antérieure** et suivre le [diagnostic d'incident](TROUBLESHOOTING.md#installation-et-apply) : une nouvelle sauvegarde de l'état partiel ne remplace pas le point de retour d'origine.

## 8. Appliquer la configuration

**But :** appliquer le profil de configuration du dépôt au système préparé. **L'APPLY n'est pas la première modification du PC** : l'installation de Fedora, la préparation des outils, le montage de `/data` et la sauvegarde pré-APPLY peuvent déjà modifier son état. Chacune possède ses préconditions et points d'arrêt dans les sections précédentes.

> [!CAUTION]
> Point de non-retour : la sauvegarde pré-APPLY doit être vérifiée et son support branché ([points de non-retour](#points-de-non-retour)).

```bash
./install.sh --apply
```

L'APPLY vérifie toutes les préconditions, puis demande de taper exactement `APPLY FEDORA 45 WORKSTATION`. Il refuse notamment :

- une exécution hors du PC physique (VM, conteneur, CI, session Live) ;
- un dépôt Git modifié ;
- un dry-run ou une baseline périmés ;
- une sauvegarde pré-APPLY absente ou inaccessible ;
- Secure Boot actif ou indéterminé.

Parmi les modules appliqués :

- **Noyau** : le dernier Linux amont stable, comparé à kernel.org, devient le défaut GRUB ; le noyau amont précédent est conservé, et un noyau Fedora signé reste disponible en secours (`installonly_limit` réglé en conséquence).
- **Données** : `/data` est contrôlé, l'arborescence de la section 4 est créée avec ses droits et labels SELinux, et XDG Documents pointe vers `/data/Documents`.

**Réussite :** l'APPLY se termine sans erreur. Un refus désigne la précondition à corriger ; ne jamais le contourner.

## 9. Redémarrer sur Linux amont N

```bash
./control.sh kernel status
sudo reboot
```

Après le redémarrage, vérifier le noyau et le socle matériel. Ces doctors sont en lecture seule :

```bash
./control.sh kernel status
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/storage-doctor
./diagnostics/data-storage-doctor
./diagnostics/graphics-doctor
./diagnostics/display-doctor
./diagnostics/media-doctor
./diagnostics/arc-compute-doctor
```

`kernel-doctor` contrôle N, N-1, le secours Fedora, le défaut GRUB et `installonly_limit` ; `data-storage-doctor` contrôle le second T705, l'arborescence de `/data`, ses droits et labels, et XDG Documents ; `graphics-doctor` et `arc-compute-doctor` exécutent de vrais essais VA-API et OpenCL sur la B580.

**Réussite :** le système a démarré sur N, le dernier stable installé, et ces doctors réussissent. `./control.sh doctor all` est plus large : certains de ses contrôles (KVM, jeu, accès distant) ne réussissent qu'après la Gate 3. Si N ne démarre pas, voir [En cas d'échec](#en-cas-déchec).

## 10. Contrôler le premier login GNOME

Le démarrage à froid de Nautilus fait partie de la certification et se mesure **avant la première ouverture de Fichiers** :

```bash
./diagnostics/nautilus-coldstart-doctor
./diagnostics/gnome-doctor
```

**Réussite :** les deux doctors réussissent, et le dossier « Documents » de Fichiers pointe vers `/data/Documents`.

## 11. Qualifier le système installé (Gate 3)

La [qualification](QUALIFICATION.md#4-gate-3--système-installé) fait foi pour cette étape. Elle s'exécute dans la vraie session GNOME, avec l'écran et les périphériques du quotidien, dans cet ordre :

1. diagnostics de l'hôte ;
2. preuves physiques : GPU, réseau, audio, affichage ;
3. enrôlement des périphériques ;
4. sauvegarde complète certifiée et restauration isolée ;
5. création et qualification de Rocky DevOps, si KVM est activé ([démarrage KVM](KVM_QUICKSTART.md)) ;
6. bureau GNOME et applications ;
7. cinq cycles de veille réels, puis matrice UX ;
8. certification finale : `./control.sh validate gate3 certify`.

Consigner chaque résultat dans la [fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md). Aucune VM n'est créée par l'APPLY : Rocky se crée explicitement, après les contrôles de l'hôte.

**Réussite :** `validate gate3 certify` réussit et crée `state/final/certified.ok` avec le bundle Golden.

## 12. Vérifier l'état certifié

```bash
./control.sh cert status
./diagnostics/software-matrix-doctor status
./diagnostics/software-matrix-doctor diff
```

`diff` montre ce qui a changé depuis la matrice logicielle de référence. À ce stade seulement, et si la Gate 3 a réellement réussi, le poste peut être décrit comme **Golden runtime-certified**. Une évolution ultérieure du noyau, du matériel ou de la configuration peut rendre ce statut `STALE` : on requalifie alors, on ne réécrit jamais un marqueur.

---

## En cas d'échec

Chaque cause ci-dessous reste une hypothèse tant que la vérification indiquée ne l'a pas confirmée.

| Symptôme | Cause possible | Vérification sûre | Correction | Nouvelle validation |
| --- | --- | --- | --- | --- |
| `ISO SHA256 mismatch` ou `Unexpected Fedora signing key` | ISO corrompue, incomplète ou autre que le média promu | Taille et nom du fichier, comparés à la [fiche Fedora 45](FEDORA45_PRIMARY.md#média-promu) | Retélécharger l'ISO et le CHECKSUM officiels | Section 1 |
| Décision Live `NO-GO` ou `A_VERIFIER` | Point en `FAIL`, ou point requis non essayé | `./control.sh validate live status` | Corriger le défaut ou faire l'essai manquant | `validate live run` |
| Import Live refusé | Autre commit, autre plan de modules ou autre PC | `git rev-parse HEAD`, comparé au SHA conservé | Revenir au commit du Live, ou refaire le contrôle Live | `validate import` |
| `baseline-doctor certify` échoue | Essai manquant, vitesse mémoire différente de l'essai, matériel non conforme | Sortie de `certify` et `./diagnostics/baseline-doctor status` | Refaire l'essai indiqué ; un défaut matériel arrête le parcours | `certify` |
| APPLY refusé : dry-run périmé | Commit, `config/local.conf` ou matériel modifiés après le dry-run | `git status` et date de la dernière retouche | Relancer le dry-run, puis la sauvegarde | Sections 6 et 7 |
| APPLY refusé : sauvegarde | Support Borg débranché ou archive introuvable | Support monté, `./diagnostics/backup-doctor` | Rebrancher le support ou refaire la sauvegarde | Section 7 |
| APPLY refusé : marqueur trop ancien | Marqueur pré-APPLY de plus de 24 h par défaut | Âge de `state/preapply-backup.ok` et `BACKUP_MAX_AGE_HOURS` | Avant le premier APPLY, refaire la sauvegarde sous l'état validé | Section 7 |
| APPLY refusé : Secure Boot | Secure Boot actif ou état illisible | `mokutil --sb-state` | Désactiver Secure Boot dans l'UEFI | Section 8 |
| APPLY commencé puis échoué | Un ou plusieurs modules ont pu modifier Fedora avant le premier échec | Rapport `reports/run-<identifiant>.json` et journaux `logs/<identifiant>/` | **Ne pas relancer automatiquement** ; qualifier l'état partiel avant de décider entre réparation et reprise en staging ([procédure](TROUBLESHOOTING.md#installation-et-apply)) | Refaire les contrôles concernés et, si reprise autorisée, les préconditions 6 à 8 |
| Démarrage sur N-1 ou échec de N | Régression du noyau N | `./control.sh kernel status`, journal du démarrage précédent | `./control.sh kernel rollback` ; si aucun noyau amont ne démarre, choisir l'entrée Fedora dans GRUB ([dépannage](TROUBLESHOOTING.md)) | `kernel-doctor` |

**Retour arrière.** L'APPLY ne supprime aucune donnée de `/data`. Pour revenir à l'état d'avant l'APPLY, restaurer l'archive pré-APPLY en staging, puis remettre les fichiers voulus à la main, selon [sauvegardes et restauration](BACKUP_RESTORE.md). Une réinstallation complète repart de la section 2 et réutilise le second T705 sans le reformater. La CI restaure une archive Borg réelle en VM ; le retour arrière après un APPLY sur le PC reste à essayer pendant la qualification.

## Après la certification

| Besoin | Guide |
| --- | --- |
| Mises à jour (`./control.sh update all`, redémarrage hors ligne, finalisation) | [Centre de contrôle](CONTROL_CENTER.md) |
| Noyau : rollback N-1, secours Fedora, retour au dernier stable | [Linux amont](UPSTREAM_LINUX.md) |
| Sauvegarde quotidienne, restauration, reprise après sinistre | [Sauvegardes et restauration](BACKUP_RESTORE.md) |
| Affichage dégradé après veille (`./repair.sh display`), autres symptômes | [Dépannage](TROUBLESHOOTING.md) |
| Machines virtuelles | [KVM au quotidien](KVM_QUICKSTART.md) |

---

## Option avancée — Kickstart

**But :** remplacer l'installation graphique de la section 2 par une installation automatisée, préparée et relue. Elle se fait **après** le contrôle Live et l'export de sa preuve.

```bash
ls -l /dev/disk/by-id/nvme-*    # lecture seule : repérer le T705 système par son numéro de série
installer/generate-fedora-kickstart.sh --release 45 --disk /dev/disk/by-id/nvme-IDENTIFIANT_SYSTEME
```

Le générateur affiche le modèle, le numéro de série et la taille du disque, puis exige une phrase de confirmation destructive exacte. Le Kickstart produit :

- efface uniquement le NVMe choisi et y installe Btrfs, sans LUKS ;
- incorpore le média approuvé et le SHA Git du dépôt, puis clone exactement ce commit ;
- ne modifie pas Secure Boot et ne lance jamais l'APPLY.

**Média :** Fedora n'accepte pas de Kickstart depuis une image Live. Démarrer l'ISO **Fedora 45 Everything netinstall** avec `inst.ks=` pointant vers le fichier généré ; les paquets viennent alors des dépôts officiels `fedora` et `updates`. L'ISO Workstation vérifiée à la section 1 reste celle du contrôle Live.

**Réussite :** le disque et le SHA incorporés sont ceux qui ont été audités, et le commit est celui du Live. Reprendre ensuite à l'import de la preuve Live (section 2), puis à la section 3. Le Kickstart ne remplace ni le contrôle Live, ni la baseline, ni la sauvegarde, ni la qualification.

## Étape suivante

Le poste installé se qualifie en Gate 3 : [qualification](QUALIFICATION.md). Pour l'usage courant ensuite, partir du [centre de contrôle](CONTROL_CENTER.md).
