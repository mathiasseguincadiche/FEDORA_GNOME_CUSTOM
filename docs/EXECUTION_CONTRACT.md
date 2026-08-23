# Contrat d'exécution

## Diagnostic

`./diagnostic.sh` est read-only. Il ne doit ni installer de paquet, ni changer un service, ni modifier un périphérique.

## Dry-run

`./install.sh --dry-run` exécute PRECHECK/PLAN/APPLY/POSTCHECK avec toutes les mutations neutralisées. Un succès écrit une preuve liée au commit Git courant.

## Configuration locale

Les paramètres spécifiques au poste réel sont placés dans `config/local.conf`, ignoré par Git. L'APPLY exige `REAL_MACHINE_APPROVED=true` dans cette configuration locale. Les secrets restent dans des fichiers externes protégés.

## APPLY

`./install.sh --apply` exige :

1. approbation explicite de la machine réelle ;
2. TTY interactif ;
3. dépôt Git propre ;
4. dry-run réussi du même commit ;
5. marker de backup pré-APPLY récent si `REQUIRE_PREAPPLY_BACKUP=true` ;
6. saisie exacte de la phrase de confirmation.

## Interdictions

- aucun formatage/partitionnement ;
- aucun `force_probe` GPU ;
- aucun dépôt Mesa/GPU expérimental ;
- aucune désactivation SELinux ;
- aucun changement C-State/ASPM/sleep-mode automatique ;
- aucun VFIO/passthrough du GPU Arc principal.
