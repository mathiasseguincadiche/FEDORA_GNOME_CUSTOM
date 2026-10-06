# ADR 0014 — Sauvegardes Borg sans chiffrement

**Statut : accepté** — remplace, pour la sauvegarde, la mention « dépôt Restic chiffré » des ADR 0002 et 0009.

## Contexte

Le propriétaire de la workstation a décidé explicitement, le 27 septembre 2026 : **aucun chiffrement, sauvegardes comprises**. Le disque système et `/data` n'étaient déjà pas chiffrés (ADR 0002).

Restic chiffre **toujours** ses dépôts : il n'existe pas de mode sans chiffrement, et une passphrase vide ne supprime pas le chiffrement. Restic ne pouvait donc pas respecter cette exigence.

## Décision

Le moteur de sauvegarde devient **Borg 1.x** (paquet Fedora `borgbackup`, 1.4 sur Fedora 44), avec un dépôt initialisé en `--encryption=none`.

- `BACKUP_ENGINE="borg"` et `BACKUP_ENCRYPTION="none"` sont les seules valeurs acceptées par le schéma de configuration.
- Tout appel à Borg passe par les fonctions `backup_engine_*` de `lib/backup_runtime.sh` : moteur, nommage des archives et politique « sans chiffrement » sont définis à un seul endroit.
- **Un dépôt chiffré est refusé** (`borg info` doit indiquer le mode `none`). Une passphrase vide est exportée volontairement : un dépôt chiffré échoue immédiatement au lieu d'attendre une saisie.
- Archives nommées `fgc-<type>-<horodatage UTC>`, avec les types `preapply`, `full` et `daily`. Le marker pré-APPLY enregistre le nom **et** l'identifiant de l'archive. L'APPLY les revérifie dans le dépôt, avec le type attendu.
- Intégrité : `borg check --verify-data` relit chaque bloc de l'archive pré-APPLY et de chaque backup complet. Pendant une restauration, Borg vérifie chaque bloc contre son empreinte.
- Rétention : `borg prune` par classe (`fgc-full-*`, `fgc-daily-*`), puis `borg compact`. Les archives pré-APPLY ne sont jamais supprimées automatiquement.
- Tout le reste du contrat fail-closed est inchangé : cible externe prouvée, confirmation avant création du dépôt, canary restauré, restauration uniquement en staging, VM arrêtées pour les disques QCOW2, runtime immuable des timers.
- Depuis 0.19.0, seul le code de création **0** permet un succès. Le code 1 peut signifier un fichier illisible ou omis : l'archive éventuellement écrite reste inspectable, mais aucun marker de succès n'est émis. Les codes 2 et plus sont également des échecs. Fermer les applications qui écrivent dans les sources avant une sauvegarde certifiée.

## Conséquences

Avantages :

- conforme à la décision du propriétaire ;
- **plus de secret à perdre** : un Fedora neuf avec `borgbackup` et le disque suffisent pour restaurer ;
- déduplication et compression (`zstd,3`) conservées ;
- dépôts distants possibles en `ssh://`.

Coûts assumés :

- **quiconque possède le disque de sauvegarde peut lire son contenu**, y compris `~/.ssh`, `~/.gnupg` et les profils de navigateur. Le disque doit être rangé comme un document sensible ;
- sans chiffrement authentifié, une modification malveillante du dépôt n'est détectée que par les empreintes vérifiées par `borg check --verify-data`, pas par une clé ;
- les dépôts Restic créés par les versions ≤ 0.17 ne sont pas migrés automatiquement. Aucune installation réelle ne les avait encore utilisés ; le module de sauvegarde désactive les anciennes unités `fedora-gnome-restic-retention.*`.

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
