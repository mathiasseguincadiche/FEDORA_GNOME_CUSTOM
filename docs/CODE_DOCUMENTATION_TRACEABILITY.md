# Traçabilité documentaire — Fedora Golden Workstation

Ce registre indique **où se trouve la source de vérité** de chaque parcours. Il ne remplace pas les guides opérateur : les commandes et paramètres doivent être vérifiés dans le code au commit utilisé.

| Parcours | Sources exécutables | Guide opérateur | Validation |
| --- | --- | --- | --- |
| Point d'entrée | `control.sh`, `lib/control_center.sh` | [Control Center](CONTROL_CENTER.md) | `tests/test_workstation_control_center_contract.sh` |
| USB Live Fedora 45 | `diagnostics/live-preflight.sh` | [Préflight Live](FEDORA45_LIVE_PREFLIGHT.md) | `.github/workflows/live-preflight.yml` |
| Installation sécurisée | `install.sh`, `installer/` | [Installation](INSTALLATION_GUIDE.md) | `.github/workflows/fedora-installer-audit.yml` |
| Promotion Fedora 45 | `scripts/development/promote-fedora45.py`, `profiles/fedora45/` | [Référence Fedora 45](FEDORA45_PRIMARY.md) | `tests/test_promote_fedora45_behavior.sh` |
| Qualité et gates | `scripts/validation/`, `.github/workflows/` | [Live USB et Gate 3](THREE_GATE_VALIDATION.md), [CI](CI_VALIDATION.md) | `tests/test_three_gate_validation_contract.sh` |
| GNOME | `modules/gnome/`, `profiles/fedora45/gnome-extensions.lock` | [GNOME](GNOME.md), [extensions](GNOME.md) | Tests d'intégration GNOME |
| Sauvegarde et restauration | `modules/backup/`, `scripts/backup/` | [Backup et restauration](BACKUP_RESTORE.md) | Contrats backup et preuve réelle de restauration |
| KVM et labo Rocky | `scripts/kvm/`, `guest/rocky-devops/` | [KVM](KVM_QUICKSTART.md), [Rocky](ROCKY_DEVOPS_READY.md) | Tests VM et qualification réelle |
| Accès distant | `config/remote.conf`, `diagnostics/remote-doctor` | [Accès distant](REMOTE_ACCESS.md) | `tests/test_remote_access_contract.sh` |
| Gouvernance | `.github/workflows/`, `.github/pull_request_template.md` | [Gouvernance](GITHUB_GOVERNANCE.md) | Checks du commit exact et contrôles sur main |

## Trois statuts à ne jamais confondre

1. **Tests CI réussis :** contrats logiciels vérifiés pour un SHA précis.
2. **Préflight Live GO :** cinq observations préinstallation réussies sur le matériel, sans autorisation d'écrire sur les SSD.
3. **Golden runtime-certified :** qualification Gate 3 réussie sur la workstation installée.

Un PASS à une étape ne vaut pas PASS aux autres. Fedora 45 / GNOME 51 est la référence d’installation neuve ; Fedora 44 reste un laboratoire historique facultatif. Le profil Fedora 45 `pending` interdit de décrire l'installation de production comme déjà autorisée.

## Règles de maintenance

- Toute modification d'un point d'entrée ou d'une option publique doit mettre à jour son guide.
- Toute modification d'un workflow doit vérifier les affirmations sur les checks obligatoires, la matrice CI et les badges.
- Toute modification de profil Fedora, de verrous d'extensions ou de média doit actualiser la documentation de compatibilité et les critères d'arrêt.
- Les numéros de version courants proviennent de `VERSION` ; l'historique détaillé reste dans `CHANGELOG.md`.
- Les captures de bureau illustratives doivent être identifiées comme telles ; les preuves physiques doivent porter leur contexte de qualification.
- Conserver les ADR et les audits historiques, même lorsqu'une décision est remplacée, en les étiquetant clairement.

## Points à auditer avant une réorganisation physique

- Liens relatifs et ancres Markdown dans le README, les guides, les ADR et les modèles d'issues.
- Chemins documentaires référencés par les tests de contrat et les scripts.
- Éventuels doublons entre guides opérateur, normes et notes historiques.
- Cohérence des informations sur Fedora 45/45, les six rôles d'extensions GNOME 51 et les protections de `main`.

**Politique de migration :** ne pas déplacer un document si son nouveau chemin risque de casser une procédure ou un test sans migration atomique des références.
