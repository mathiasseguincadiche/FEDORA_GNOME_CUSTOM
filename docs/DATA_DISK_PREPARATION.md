# Préparer ou réutiliser le disque de données `/data`

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — contrat d'identité relu contre `config/hardware.conf`, `lib/persistent_data_identity.py` et `diagnostics/baseline-doctor` ; opérations de partitionnement et montage **non exécutées** — matériel : non vérifié

**Objectif :** rendre le second Crucial T705 disponible en EXT4 sous `/data`, sans toucher au disque système ni détruire un disque déjà utilisé. Le [guide d'installation](INSTALLATION_GUIDE.md#4-préparer-le-second-t705-pour-data) fixe le moment où exécuter cette procédure : **après l'installation de Fedora sur le T705 système, avant la baseline et l'APPLY**.

Cette opération est **manuelle** : le dépôt n'efface et ne partitionne jamais ce SSD. Le contrôle final du projet exige deux SSD NVMe physiques de modèle `CT1000T705SSD3`, l'un pour `/`, l'autre pour `/data`, avec des numéros de série distincts. Les noms `/dev/nvme0n1` et `/dev/nvme1n1` ne sont **pas** des identités stables.

## À décider avant toute écriture

| Situation constatée | Parcours | Écriture sur le disque de données |
| --- | --- | --- |
| Second T705 déjà rempli, données à conserver | [Réutiliser l'EXT4 existant](#a--réutiliser-un-disque-contenant-des-données) | **Aucun formatage ni repartitionnement** |
| Second T705 neuf, vide et dédié au projet | [Préparer un disque neuf](#b--préparer-un-disque-neuf) | **Destructif**, seulement après identification et autorisation explicites |
| État inconnu, autre modèle, plusieurs partitions ambiguës, RAID/LUKS/LVM inattendu | **Arrêt** | Aucune ; clarifier le stockage avant de continuer |

**Prérequis :** Fedora 45 déjà démarré depuis le T705 système, terminal avec `lsblk`, `findmnt`, `blkid`, `cfdisk`, `mkfs.ext4` et `sudo`, accès administrateur, numéros de série physiques connus. Prévoir une sauvegarde indépendante et **restaurable** de tout contenu à conserver. Un disque déclaré neuf par erreur peut contenir des données irremplaçables.

## 1. Identifier les deux SSD sans modifier leur contenu

Depuis le Fedora **installé**, avant toute modification :

```bash
# Voir modèles, numéros de série, tailles et montages.
lsblk -e7 -o NAME,TYPE,MODEL,SERIAL,SIZE,FSTYPE,UUID,MOUNTPOINTS
findmnt -no SOURCE,TARGET,FSTYPE,UUID /

# Examiner les noms persistants réellement présents sur ce PC.
ls -l /dev/disk/by-id/
```

Noter sur papier ou dans un inventaire privé : numéro de série du SSD qui porte `/`, numéro de série du second T705 et état de ses partitions. Comparer aux identités relevées en [Gate 2](FEDORA45_LIVE_PREFLIGHT.md). **Arrêt immédiat** si les séries ne sont pas distinctes et connues, si un disque affiche des données non sauvegardées ou si les chemins ne sont pas univoques.

Dans les commandes ci-dessous, `CHEMIN_BY_ID_DU_T705_DATA` et `CHEMIN_BY_ID_DE_SA_PARTITION_EXT4` sont des **repères à remplacer** après lecture de `ls -l /dev/disk/by-id/` ; ils ne sont jamais à exécuter tels quels. Un disque et une partition n'ont pas le même chemin.

## A — Réutiliser un disque contenant des données

1. **Ne lancer ni `cfdisk`, ni `mkfs.ext4` sur ce disque.** Vérifier la partition EXT4 et son UUID avec `lsblk -f`, sans copier des fichiers avant le montage.
2. Confirmer que l'UUID appartient à la **partition du second T705** et non à `/`. Si le système de fichiers est inconnu ou inaccessible, arrêter et traiter sa récupération séparément.
3. Passer à la [déclaration persistante du montage](#2-déclarer-et-vérifier-le-montage-data). Conserver l'UUID existant.

## B — Préparer un disque neuf

> [!CAUTION]
> **Point de non-retour :** créer une table de partitions ou exécuter `mkfs.ext4` efface les structures de stockage du disque choisi. La commande agit immédiatement ; une erreur ne peut pas être réparée par la sauvegarde pré-APPLY du projet, qui n'existe pas encore. Ne continuer que si le propriétaire confirme avoir identifié le SSD **neuf, vide, distinct de `/`**, et accepte son effacement.

### Contrôle du disque sélectionné

```bash
# Choisir la VRAIE entrée stable du second T705 après l'inventaire.
DATA_DISK="/dev/disk/by-id/CHEMIN_BY_ID_DU_T705_DATA"
readlink -e -- "$DATA_DISK"     # doit pointer vers le second SSD, jamais celui de /
lsblk -o NAME,TYPE,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINTS "$DATA_DISK"
```

**Arrêt :** un numéro de série inattendu, un montage actif, des partitions contenant des données, ou une correspondance incertaine interdit la suite. Recommencer l'inventaire plutôt que deviner un `/dev/nvme…`.

### Partitionnement interactif, puis formatage explicite

```bash
# INTERACTIF et DESTRUCTIF après confirmation humaine :
sudo cfdisk "$DATA_DISK"
```

Pour un disque **réellement neuf** : choisir une table **GPT**, créer **une seule partition Linux** occupant l'espace destiné à `/data`, relire **l'identité du disque et le résumé de la table**, puis confirmer `Write` uniquement après accord. Quitter sans écrire si un détail diffère. **Aucune commande du dépôt ne réalise cette opération à votre place.**

Recontrôler les chemins présents après l'écriture :

```bash
lsblk -o NAME,TYPE,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINTS "$DATA_DISK"
ls -l /dev/disk/by-id/

# Choisir la partition stable nouvellement créée, PAS le disque entier.
DATA_PART="/dev/disk/by-id/CHEMIN_BY_ID_DE_SA_PARTITION_EXT4"
readlink -e -- "$DATA_PART"
lsblk -o NAME,TYPE,MODEL,SERIAL,SIZE,FSTYPE,MOUNTPOINTS "$DATA_PART"
```

**Dernier arrêt :** relire à nouveau l'identité du **parent physique** de `DATA_PART`, s'assurer qu'elle est la seule partition neuve prévue et qu'elle n'est pas montée. Lorsque ces contrôles et l'accord d'effacement sont confirmés :

```bash
# DESTRUCTIF : formate uniquement la partition DATA_PART vérifiée.
sudo mkfs.ext4 -L FGC_DATA "$DATA_PART"

# Résultat attendu : TYPE=ext4, UUID valide sur cette partition.
sudo blkid "$DATA_PART"
```

Le formatage ne monte pas automatiquement la partition et n'enrôle pas le SSD. Si `mkfs.ext4` signale des données existantes, des erreurs d'E/S ou une cible inattendue, **arrêter** : ne pas forcer.

## 2. Déclarer et vérifier le montage `/data`

Pour **les deux parcours**, relever l'UUID de la partition EXT4 sélectionnée (`sudo blkid`), et le comparer à `lsblk -f`. Il doit être distinct de celui de `/`.

```bash
sudo install -d -m 0755 /data  # point de montage ; ne crée pas de données utilisateur
sudo cp -a --backup=numbered /etc/fstab /etc/fstab.avant-fgc-data  # conserve les copies précédentes
sudoedit /etc/fstab
```

Ajouter **une seule ligne**, en remplaçant `UUID_EXT4_DU_T705_DATA` par l'UUID **réel** de la partition :

```fstab
UUID=UUID_EXT4_DU_T705_DATA /data ext4 defaults 0 2
```

Avant de monter, vérifier que `/etc/fstab` ne comporte **aucune autre entrée** pour `/data`, que le chemin `/data` ne contient pas déjà des fichiers créés sur le SSD système et que l'UUID désigne bien le second T705. Ne jamais monter par-dessus un répertoire dont les données doivent être conservées. Une erreur dans `/etc/fstab` peut empêcher un démarrage normal : corriger à partir de la copie de sécurité si nécessaire.

```bash
sudo findmnt --verify --verbose  # vérifie les entrées fstab sans monter
sudo mount /data                 # prend la nouvelle entrée /etc/fstab
findmnt -no SOURCE,TARGET,FSTYPE,UUID /data
lsblk -f
./diagnostics/baseline-doctor storage-identity
```

**Réussite :** `findmnt` indique une cible `/data` dédiée, de type `ext4`, distincte du SSD de `/` ; `storage-identity` retrouve les deux T705 attendus. Si un contrôle échoue, **ne pas enrôler** le disque et ne pas lancer l'APPLY. Après correction et confirmation du montage persistant, redémarrer lors d'un créneau maîtrisé et répéter `findmnt` ; ne pas considérer un montage manuel temporaire comme suffisant.

## 3. Enrôler le disque et reprendre l'installation

Reprendre le numéro de série exact du second T705 retourné par `storage-identity` :

```bash
./diagnostics/baseline-doctor enroll-data NUMERO_DE_SERIE_DU_T705_DATA
./diagnostics/baseline-doctor storage-identity
```

L'enrôlement est une écriture **de l'identité approuvée**, pas un formatage. Il lie le SSD, son système de fichiers et l'UUID au matériel attendu. Un changement ultérieur de SSD ou de montage doit provoquer un refus, pas une adaptation silencieuse.

Revenir à la [section 4 du guide d'installation](INSTALLATION_GUIDE.md#4-préparer-le-second-t705-pour-data), puis continuer sur la baseline et le dry-run. **Les sous-dossiers `/data/Documents`, `/data/Projets`, `/data/libvirt`, etc. seront créés ou normalisés par l'APPLY** ; ne pas conclure à un échec de `data-storage-doctor` avant cette phase s'ils n'existent pas encore.

## Échec, retour arrière et limites

| Symptôme | Conduite sûre |
| --- | --- |
| Mauvaise série / parent physique incertain | Aucun formatage, montage ou enrôlement ; reprendre l'inventaire |
| Partition non vide ou fichiers inattendus | Arrêt ; préserver le contenu et décider explicitement de sa récupération |
| Erreur de syntaxe fstab | Restaurer l'entrée précédente depuis la copie locale, relancer `findmnt --verify` ; ne pas masquer l'erreur par un montage sur `/` |
| `/data` monte sur le mauvais SSD ou n'est pas EXT4 | Arrêt ; ne pas exécuter `install.sh --apply` ; corriger montage et identité |
| Disque formaté par erreur | **Ne plus écrire sur le disque** ; escalader vers une récupération de données spécialisée. Le projet ne possède pas de commande de restauration du contenu effacé |

**Portée de cette documentation :** commandes relues contre le contrat de stockage, **pas éprouvées sur le matériel de production**. Une procédure d'installation n'est certifiée qu'après une exécution physique autorisée et des preuves de qualification Gate 3 conservées.
