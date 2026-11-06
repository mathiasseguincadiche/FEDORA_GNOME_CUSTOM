# Reprise isolée avant qualification Golden

> Mise à jour : 2026-11-05 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-05 — résumé d'exécution ajouté et relu contre les étapes de ce guide ; commandes relues le 2026-11-04 contre `scripts/backup/` (`backup-now.sh --staging-root`, `restore.sh list|verify|restore`, `disaster-recovery.sh`), non rejoué — matériel : non vérifié

Objectif : démontrer que les données, Fedora et les VM peuvent être récupérés, puis démarrés, sans écrire sur les disques d'origine. Les essais GitHub sont décrits dans [le laboratoire CI](FEDORA_GNOME_CI_LAB.md) ; cette procédure couvre la vraie configuration et les archives de production.

## Résumé d'exécution

L'exercice se joue sur plusieurs supports et plusieurs sessions : ce résumé dit où en est la reprise d'un coup d'œil. Reprendre à la première case non cochée, en relisant la section d'origine :

- [ ] Commit, configuration, plan de modules et preuve Live conservés hors de la workstation
- [ ] Sauvegarde complète sans VM créée, doctor consulté, plan de récupération lu
- [ ] Disques cibles physiquement séparés, identifiés par numéro de série
- [ ] Fichiers restaurés en staging et comparés (contenu, modes, liens, propriétaires)
- [ ] Fedora reconstruite sur le disque de test, convergence rejouée
- [ ] VM reprise depuis l'export manuel, isolation vérifiée
- [ ] Preuves conservées, puis reprise de la Gate 3

Ce résumé ne remplace pas les critères d'acceptation de chaque étape : un état ambigu ou un membre manquant arrête l'exercice.

## Préparer la preuve

Conserver hors de la workstation le commit exact, la configuration effective, le plan de modules et la preuve Live native correspondante, l'identité du dépôt et le nom/id de l'archive. Borg doit être non chiffré. Il ne faut aucune clé de chiffrement ; il faut conserver les accès au dépôt, le média Fedora verrouillé et le support physique de sauvegarde.

Créer une sauvegarde complète de l'hôte et des données utilisateur, avec un staging dimensionné, **sans inclure de VM** :

```bash
scripts/backup/backup-now.sh --staging-root /chemin/absolu/staging
./diagnostics/backup-doctor
scripts/backup/disaster-recovery.sh
```

Lire le plan de récupération de l'hôte et le commit qu'il désigne. Les archives Borg **ne couvrent ni les disques ni les métadonnées libvirt**. Une reprise de VM dépend uniquement de l'export manuel que le propriétaire a choisi de réaliser et de conserver séparément. Les archives `fgc-pending-*` ne sont jamais une base de reprise automatique.

## Séparer physiquement les cibles

Utiliser un support de récupération neuf/jetable et identifier chaque disque par numéro de série et `/dev/disk/by-id`. Déconnecter les deux T705 originaux lors d'une réinstallation sur support de test. Le support externe de sauvegarde reste distinct du disque cible. Ne réutiliser aucun Kickstart visant un numéro de série de production.

Pour la copie VM, arrêter l'originale et utiliser un hôte libvirt de laboratoire séparé. Conserver les identités de l'export sans définir deux domaines portant le même UUID sur le même hôte. Aucun réseau de production, partage de données, SFTP ou périphérique passthrough ne doit être attaché à la copie. Démarrer sans carte réseau, ou dans un réseau de laboratoire sans routage sortant, NAT ni accès LAN.

Le staging doit pouvoir contenir les fichiers et disques extraits avec la réserve prévue ; vérifier la capacité avant copie. Un laboratoire virtuel ne permet pas de contourner l'exigence de matériel physique de l'APPLY de production.

## 1. Restaurer les fichiers

Lister et vérifier le dépôt, puis extraire l'archive choisie vers un staging vide :

```bash
scripts/backup/restore.sh list
scripts/backup/restore.sh verify
scripts/backup/restore.sh restore NOM_EXACT_DE_L_ARCHIVE /chemin/du/staging/vide
```

Le chemin doit rester sous `BACKUP_RESTORE_STAGING_ROOT`. L'extraction refuse les cibles de production et les répertoires déjà remplis. Comparer contenu, modes, liens symboliques et propriétaires, y compris les noms avec espaces. Tester au moins un document, un réglage GNOME et une donnée applicative. Vérifier les exclusions de secrets attendues.

**Acceptation :** archive exacte vérifiée, fichiers lisibles et identiques. Conserver hash, compte rendu de comparaison et emplacement du staging. La réussite de cette étape ne prouve pas un système amorçable.

## 2. Reconstruire Fedora sur support de test

Vérifier le média Workstation selon [le guide](INSTALLATION_GUIDE.md). Installer uniquement sur le disque de récupération identifié par son propre numéro de série. Récupérer le commit et la configuration indiqués par l'archive. Restaurer d'abord en staging ; remettre ensuite les seuls fichiers nécessaires en respectant propriétaires et labels SELinux, sans écraser globalement `/etc`, `/boot` ou les périphériques.

Sur le matériel physique autorisé, suivre la baseline, le dry-run, la sauvegarde pré-APPLY et l'APPLY du guide. Redémarrer, vérifier le noyau réellement utilisé, GNOME/Wayland, Nautilus/Ptyxis, données et services. Rejouer la convergence et archiver les diagnostics. Une VM peut servir à des exercices de fichiers et de démarrage isolés ; l'APPLY de production y reste bloqué.

**Acceptation :** démarrage autonome du disque de récupération, données accessibles, diagnostics cohérents et convergence répétable. Documenter les applications/services réellement réinstallés et toute partie non récupérée.

## 3. Reprendre une VM

Si le propriétaire dispose d'un export **manuel** de la VM, réunir les composants de cet export (hors Borg) :

- XML/définition et UUID du domaine ;
- disques autonomes ou toutes les dépendances de leur backing chain ;
- NVRAM UEFI associée ;
- état swtpm associé et propriétaire correct uniquement si cet export comporte un TPM émulé.

Ne mélanger aucun état TPM/NVRAM d'une autre date ou d'un autre domaine. Remettre ces membres ensemble, VM arrêtée, puis contrôler droits et labels SELinux avant démarrage. Adapter les chemins vers le stockage du laboratoire et supprimer les interfaces/partages de production avant de définir le domaine.

Démarrer la copie isolée. Vérifier système invité, documents et applications. Effectuer un redémarrage supplémentaire et revérifier les données. Préserver l'original jusqu'à la fin de l'essai.

**Acceptation :** invité amorçable, état UEFI correspondant (et TPM si présent), données accessibles et isolation effective. Le test canari TPM Linux de la CI reste un test logiciel distinct ; Rocky ne nécessite pas de TPM émulé.

## Preuves minimales et arrêt sur échec

| Essai | Preuves à conserver |
|---|---|
| Fichiers | Commit/config, dépôt, nom/id d'archive, verify-data, hash/modes/liens comparés |
| Fedora | Média/hash, série du disque cible, étapes de reconstruction, noyau/boot, diagnostics GNOME et convergence |
| VM | Nom/UUID, membres disque/NVRAM/swtpm, réseau isolé, journal du boot et données vérifiées |

Une archive incomplète, un membre manquant, une erreur Borg, un disque cible ambigu, un démarrage en échec ou une fuite réseau arrête l'exercice. Garder les preuves d'échec et corriger avant reprise ; aucun statut ne devient PASS sur la seule absence d'erreur dans un ancien rapport.

Après ces essais, reprendre la [Gate 3](QUALIFICATION.md#4-gate-3--système-installé). La preuve Live doit être rejouée après toute modification du commit ou du plan de modules.
