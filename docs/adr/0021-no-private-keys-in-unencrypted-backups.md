# ADR 0021 — Aucune clé privée dans les sauvegardes non chiffrées

Statut : accepté. Précise ADR 0014 ; décision utilisateur du 27 octobre 2026.

## Contexte

ADR 0014 garde des dépôts Borg sans chiffrement. Les sauvegardes quotidiennes et complètes incluaient pourtant `~/.ssh` et `~/.gnupg` : la perte ou le vol du SSD externe exposait les clés privées SSH et GnuPG, donc l'accès à GitHub, aux serveurs et aux signatures.

## Décision

- Les dépôts restent non chiffrés (ADR 0014 inchangée sur ce point).
- Tout dossier `.ssh` ou `.gnupg`, à n'importe quelle profondeur, est exclu de **toutes** les archives (`preapply`, `full`, `daily`). L'exclusion est appliquée dans `backup_engine_create`, seul point d'appel à `borg create` : aucune configuration (`DAILY_BACKUP_EXTRA_PATHS`, ancien `local.conf`) ne peut la lever.
- `.ssh` et `.gnupg` sont retirés des sources par défaut.
- Les clés se sauvegardent à part, dans un emplacement chiffré (Bitwarden ou support chiffré) ; la procédure est décrite dans [BACKUP_RESTORE.md](../BACKUP_RESTORE.md).

## Alternative écartée

Chiffrer tout le dépôt Borg (`repokey-blake2`) protégerait aussi les profils de navigateur, mais revient sur la décision d'ADR 0014 (aucune passphrase à perdre). Elle reste possible plus tard, par une nouvelle ADR.

## Conséquences

- Une restauration ne recrée ni `~/.ssh` ni `~/.gnupg` : clés, `known_hosts`, `config` et `authorized_keys` sont à restaurer depuis leur sauvegarde dédiée, ou à régénérer et redéclarer.
- Un fichier dont le nom commence seulement par `.ssh` (par exemple `.ssh-notes.txt`) reste sauvegardé : seuls les dossiers exactement nommés `.ssh` et `.gnupg` sont exclus.
- Les profils de navigateur restent lisibles sur le disque de sauvegarde ; le disque doit toujours être rangé comme un document sensible.
