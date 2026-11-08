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

## Précision technique — archive système imbriquée

Les sauvegardes `preapply` et `full` créent d'abord `fedora-system-config.tar.gz` à partir de `/etc` et `/boot`, puis confient **ce fichier unique** à Borg. Les exclusions `*/.ssh` et `*/.gnupg` appliquées par Borg ne peuvent pas retirer des fichiers **à l'intérieur** du tarball. Ce point justifie un contrôle supplémentaire **avant** sa création dans les deux scripts.

`BACKUP_SYSTEM_CONFIG_TAR_EXCLUDES` (dans `lib/backup_runtime.sh`) exclut explicitement les emplacements usuels de secrets : empreintes de mots de passe `shadow`/`gshadow`, clés privées d'hôte SSH, connexions NetworkManager, WireGuard/OpenVPN, répertoires de clés privées TLS, Kerberos, authentification des conteneurs et état libvirt. Une archive factice est inspectée par `tests/test_backup_private_keys_behavior.sh` pour empêcher une réintroduction accidentelle de ces fichiers.

**Limite assumée :** cette liste protège des emplacements **connus**, pas de tous les secrets arbitraires qu'un logiciel peut créer sous `/etc`. Le choix d'un dépôt non chiffré demeure ; les archives anciennes ne sont ni réécrites ni supprimées par ce correctif. Une restauration des éléments exclus exige une reconfiguration ou une sauvegarde sensible séparée, protégée par un support approprié. Ne jamais présenter Borg non chiffré comme une protection de confidentialité.
