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

1. runtime bare-metal réel ;
2. approbation explicite de la machine réelle ;
3. TTY interactif ;
4. dépôt Git propre ;
5. dry-run réussi du même commit ;
6. baseline hardware valide pour le fingerprint courant ;
7. marker de backup pré-APPLY récent, vérifié et lié au même commit si `REQUIRE_PREAPPLY_BACKUP=true` ;
8. saisie exacte de la phrase de confirmation.

Une VM, WSL2, un conteneur ou la CI ne peuvent jamais ouvrir ce gate.

## LAB GNOME VirtualBox

Le GATE 2 graphique dispose d'un entrypoint **séparé** :

```bash
scripts/lab/apply-gnome-virtualbox.sh --plan
scripts/lab/apply-gnome-virtualbox.sh --apply
scripts/lab/apply-gnome-virtualbox.sh --check
```

Ce LAB n'appelle ni l'orchestrateur complet ni `apply_gate_open`. Il exige Fedora 44, GNOME Shell 50, Wayland et une identité Oracle VirtualBox concordante entre `systemd-detect-virt` et DMI.

Sa surface de mutation est limitée aux utilitaires nécessaires et à l'ergonomie GNOME du GATE 2 : boutons de fenêtres, DING, `~/Bureau`, Corbeille et Show Desktop Plus. Kernel, firmware, hardware, stockage, KVM/libvirt, firewall et backup production restent exclus.

Le doctor LAB vérifie explicitement que le gate production et la baseline bare-metal sont toujours refusés en VirtualBox.

Voir [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).

## Interdictions

- aucun formatage/partitionnement ;
- aucun `force_probe` GPU ;
- aucun dépôt Mesa/GPU expérimental ;
- aucune désactivation SELinux ;
- aucun changement C-State/ASPM/sleep-mode automatique ;
- aucun VFIO/passthrough du GPU Arc principal ;
- aucun contournement du gate bare-metal via le LAB VirtualBox.
