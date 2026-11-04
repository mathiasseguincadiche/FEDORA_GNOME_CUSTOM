# Guide d'installation neuve — Fedora 45 Workstation / GNOME 51

> Mise à jour : 2026-11-04 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-04 — commandes, sous-commandes et garde-fous relus contre le code de `main` — matériel : non vérifié

Ce guide installe le poste de bout en bout : vérification du média, contrôle du PC depuis le Live USB, installation de Fedora, préparation, application de la configuration, puis qualification. Il fait foi pour **l'ordre des opérations** ; la [qualification](QUALIFICATION.md) fait foi pour **les critères** de chaque preuve et pour le détail de la Gate 3.

**À la fin de ce guide :** le PC tourne sous Fedora 45 avec la configuration du projet appliquée, et chaque étape a laissé une preuve vérifiable. Comprendre d'abord pourquoi l'APPLY peut refuser : [notions clés](CONCEPTS.md), points 1 à 4.

**Public :** l'opérateur qui installe le PC physique cible.
**Résultat attendu :** une Fedora 45 installée, convergée, redémarrée sur Linux amont, puis certifiée par la Gate 3. Le poste n'est « Golden runtime-certified » qu'après ce dernier contrôle.

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
| Préinstaller | 1 et 2 | Média authentifié, observations Live `GO` et preuve exportée |
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

---

## 1. Vérifier le média Fedora 45

**But :** prouver que l'ISO à écrire sur la clé USB est bien le média final promu, signé par Fedora.

**Où :** une machine Linux disposant du dépôt, de `gpgv`, `python3` et `sha256sum`, avant d'écrire la clé.

Le verrou `installer/fedora45-media.lock` fixe le média attendu : `Fedora-Workstation-Live-45-1.4.x86_64.iso`, SHA-256 `68338c6bfe4f0d64151f2e47efe9f44a8855ad05b460e56b844fb3fa2c9a3beb`. Le vérificateur demande un trousseau contenant la clé Fedora 45. Sur une Fedora, il se prépare à partir du paquet `fedora-gpg-keys` ; ailleurs, la clé publique est sur la [page sécurité de Fedora](https://fedoraproject.org/security/).

```bash
# Écrit la clé Fedora 45 au format attendu par gpgv dans ./fedora45.gpg ; ne modifie rien d'autre.
gpg --dearmor -o fedora45.gpg /usr/share/pki/rpm-gpg/RPM-GPG-KEY-fedora-45-primary

installer/verify-fedora-media.sh --release 45 \
  --iso /chemin/Fedora-Workstation-Live-45-1.4.x86_64.iso \
  --checksum /chemin/Fedora-Workstation-45-1.4-x86_64-CHECKSUM \
  --keyring fedora45.gpg
```

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

### Installer Fedora sur le T705 système

Lancer l'installateur depuis la session Live.

1. Identifier le T705 système **par son numéro de série**, jamais par un nom comme `/dev/nvme0n1`, qui peut changer d'un démarrage à l'autre.
2. Choisir une installation Btrfs, sans LUKS, conformément à l'[ADR 0002](adr/0002-no-secureboot-no-local-luks.md).
3. Ne pas toucher au second T705, réservé à `/data` : le dépôt ne le partitionne ni ne le formate jamais.
4. Relire le récapitulatif des changements de stockage avant de confirmer.

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

Ce disque conserve les documents, projets, ISO, jeux et disques de VM lors d'une réinstallation du système. S'il contient déjà des données, réutiliser son EXT4 tel quel. S'il est neuf, le formater soi-même en EXT4, après avoir vérifié son numéro de série. Le monter durablement sur `/data`, de préférence par UUID dans `/etc/fstab`, puis :

```bash
findmnt /data                                            # lecture seule
./diagnostics/baseline-doctor storage-identity           # lecture seule : modèles, séries, montages
./diagnostics/baseline-doctor enroll-data NUMERO_DE_SERIE_DU_T705_DATA
lsblk -f                                                 # lecture seule
```

Recopier le numéro de série affiché par `storage-identity` ; ne pas le deviner. L'enrôlement enregistre modèles, séries, WWN et UUID. Un changement de disque ou de montage invalide ensuite la baseline et bloque les écritures sur `/data`.

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

Les essais durent environ deux heures et demie au total : 60 minutes par passe mémoire et 30 minutes de charge CPU. Le projet ne change jamais les réglages de l'UEFI ; chaque essai vérifie la vitesse réellement configurée. Les essais NVMe écrivent un fichier temporaire, jamais sur le disque brut.

**Réussite :** `certify` réussit. Le profil d'écran certifié est alors enregistré dans `~/.local/state/fedora-gnome-custom/display-profile.env`. Un échec matériel arrête le parcours.

## 6. Lancer le dry-run final

**But :** exécuter tout le plan sans rien modifier, et produire une preuve liée à l'état exact qui sera appliqué.

Fixer d'abord la configuration définitive dans `config/local.conf` :

```text
HOST_RELEASE="45"
REAL_MACHINE_APPROVED="true"
```

Ce drapeau confirme que ce PC est la machine réelle ; il ne contourne aucun verrou. Lancer ensuite :

```bash
./install.sh --dry-run
```

Le dry-run exécute precheck, plan, apply et postcheck avec toutes les mutations neutralisées. Sa preuve est liée au commit, à la configuration effective, au plan de modules et à l'empreinte matérielle.

**Réussite :** le dry-run se termine sans module en échec. Toute modification ultérieure du commit, de `config/local.conf` ou du matériel impose de le relancer, puis de refaire la sauvegarde.

## 7. Créer la sauvegarde pré-APPLY

**But :** disposer d'une sauvegarde Borg vérifiée et restaurable de l'état exact d'avant l'APPLY.

```bash
./prepare-preapply-backup.sh
```

Le script demande la phrase de confirmation définie dans `config/backup.conf`, puis enchaîne :

```text
cible externe prouvée (ext4, 20 Gio libres au minimum)
  → archive Borg fgc-preapply-…
  → borg check --verify-data
  → restauration d'un fichier canari
  → marqueur lié au même état que le dry-run
```

**Réussite :** le script se termine en confirmant le marqueur. Au moment de l'APPLY, le projet rouvre réellement le dépôt Borg et vérifie que l'archive exacte existe toujours : le marqueur seul ne suffit pas. Garder le support externe branché.

## 8. Appliquer la configuration

**But :** faire converger le PC vers la configuration du dépôt. **C'est la seule étape qui modifie réellement le système.**

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
| APPLY refusé : Secure Boot | Secure Boot actif ou état illisible | `mokutil --sb-state` | Désactiver Secure Boot dans l'UEFI | Section 8 |
| Démarrage sur N-1 ou échec de N | Régression du noyau N | `./control.sh kernel status`, journal du démarrage précédent | `./control.sh kernel rollback` ; si aucun noyau amont ne démarre, choisir l'entrée Fedora dans GRUB ([dépannage](TROUBLESHOOTING.md)) | `kernel-doctor` |

**Retour arrière.** L'APPLY ne supprime aucune donnée de `/data`. Pour revenir à l'état d'avant l'APPLY, restaurer l'archive pré-APPLY en staging, puis remettre les fichiers voulus à la main, selon [sauvegardes et restauration](BACKUP_RESTORE.md). Une réinstallation complète repart de la section 2 et réutilise le second T705 sans le reformater.

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
