# Contrat d'exécution

## Diagnostic

`./diagnostic.sh` est read-only. Il ne doit ni installer de paquet, ni changer un service, ni modifier un périphérique.

## Dry-run

`./install.sh --dry-run` exécute PRECHECK/PLAN/APPLY/POSTCHECK avec toutes les mutations neutralisées. Un succès écrit une preuve liée au commit Git courant.

Un dry-run exécuté hors bare-metal peut s'arrêter sur une preuve matérielle volontairement indisponible. Ce refus doit rester contrôlé et non nul ; il ne constitue jamais une autorisation d'APPLY.

## Configuration locale

Les paramètres spécifiques au poste réel sont placés dans `config/local.conf`, ignoré par Git. L'APPLY exige `REAL_MACHINE_APPROVED=true` dans cette configuration locale. Les secrets restent dans des fichiers externes protégés.

## APPLY production

`./install.sh --apply` est exclusivement bare-metal et exige :

1. runtime bare-metal réel sur Fedora installé, hors session Live ;
2. Fedora 45 réellement démarré avec `HOST_RELEASE=45` et un profil final promu `ready` ; une autre version ou un profil `pending` sont refusés ;
3. approbation explicite de la machine réelle ;
4. TTY interactif ;
5. dépôt Git propre ;
6. dry-run réussi du même commit ;
7. baseline hardware valide pour le fingerprint courant ;
8. marker de backup pré-APPLY récent, vérifié et lié au même commit si `REQUIRE_PREAPPLY_BACKUP=true` ;
9. saisie exacte de `APPLY FEDORA 45 WORKSTATION`.

Une VM, WSL2, un conteneur ou la CI ne peuvent jamais ouvrir ce gate.

## Live USB avant installation

`./control.sh validate live run` observe le matériel et recueille les essais humains sans installer de paquet ni modifier les SSD. Le compte rendu est exporté vers un support externe, puis importé sur le système installé au même commit. Voir [le guide Live](FEDORA45_LIVE_PREFLIGHT.md).

La session Live est temporaire. L'APPLY de production et la certification finale exigent Fedora installé sur le SSD ; ils restent refusés depuis le Live.

## Interdictions

- aucun formatage/partitionnement ;
- aucun `force_probe` GPU ;
- aucun dépôt Mesa/GPU expérimental ;
- aucune désactivation SELinux ;
- aucun changement C-State/ASPM/sleep-mode automatique ;
- aucun VFIO/passthrough du GPU Arc principal ;
- aucun contournement du gate du système installé depuis le Live ou une VM.
