# Contrat d'exécution

## Diagnostic

`./diagnostic.sh` est read-only. Il ne doit ni installer de paquet, ni changer un service, ni modifier un périphérique.

## Dry-run

`./install.sh --dry-run` exécute PRECHECK/PLAN/APPLY/POSTCHECK avec toutes les mutations neutralisées. Un succès écrit une preuve liée au commit Git courant.

## APPLY

`./install.sh --apply` exige :

1. TTY interactif ;
2. dépôt Git propre ;
3. dry-run réussi du même commit ;
4. marker de backup pré-APPLY récent si `REQUIRE_PREAPPLY_BACKUP=true` ;
5. saisie exacte de la phrase de confirmation.

## Interdictions

- aucun formatage/partitionnement ;
- aucun `force_probe` GPU ;
- aucun dépôt Mesa/GPU expérimental ;
- aucune désactivation SELinux ;
- aucun changement C-State/ASPM/sleep-mode automatique ;
- aucun VFIO/passthrough du GPU Arc principal.
