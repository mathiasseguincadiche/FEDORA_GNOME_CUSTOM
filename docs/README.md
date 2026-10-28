# Documentation

La cible d'installation neuve est **Fedora 45 Workstation / GNOME 51**. Son profil reste `pending` jusqu'à la promotion du média final ([fiche Fedora 45](FEDORA45_PRIMARY.md)).

## Par besoin

| Je veux… | Lire |
|---|---|
| Comprendre le projet | [Vision](VISION.md), puis [architecture](ARCHITECTURE_PEDAGOGIQUE.md) |
| Installer ce PC | [Contrôle Live](FEDORA45_LIVE_PREFLIGHT.md), puis [installation](INSTALLATION_GUIDE.md) |
| Utiliser et entretenir le poste | [Centre de contrôle](CONTROL_CENTER.md), [maintenance](DESKTOP_LIFECYCLE.md), [sauvegardes](BACKUP_RESTORE.md) |
| Le bureau, les jeux, les VM | [GNOME](GNOME.md), [Gaming](GAMING.md), [démarrage KVM](KVM_QUICKSTART.md) |
| Résoudre un problème | [Dépannage](TROUBLESHOOTING.md) |
| Prouver que la machine est prête | [Qualification](QUALIFICATION.md) et sa [fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) |
| Contribuer | [Guide du contributeur](../CONTRIBUTING.md), [CI](CI_VALIDATION.md), [décisions](adr/README.md) |

Pour l'usage quotidien, tout part de `./control.sh`. Le parcours d'installation est :

**Live USB → installation → configuration définitive → baseline → dry-run → sauvegarde vérifiée → APPLY → redémarrage → Gate 3.**

Le Live USB ne déverrouille jamais `install.sh --apply` ; la CI ne certifie jamais le matériel.

## Tous les guides

### Projet et règles

- [Vision](VISION.md) · [architecture expliquée](ARCHITECTURE_PEDAGOGIQUE.md) · [architecture de référence](GOLDEN_WORKSTATION.md)
- [Cahier des charges](CAHIER_DES_CHARGES.md) · [contrat d'exécution](EXECUTION_CONTRACT.md)
- [Politique de sécurité de l'hôte](HOST_SECURITY_POLICY.md) · [provenance des logiciels](SUPPLY_CHAIN.md) · [inventaire logiciel](SOFTWARE_INVENTORY.md)
- [Glossaire](GLOSSARY.md) · [décisions d'architecture (ADR)](adr/README.md)

### Installation et qualification

- [Fiche Fedora 45](FEDORA45_PRIMARY.md) · [contrôle Live USB](FEDORA45_LIVE_PREFLIGHT.md) · [guide d'installation](INSTALLATION_GUIDE.md)
- [Qualification](QUALIFICATION.md) · [fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) · [reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md)

### Usage quotidien

- [Centre de contrôle](CONTROL_CENTER.md) · [maintenance du poste](DESKTOP_LIFECYCLE.md) · [sauvegardes et restauration](BACKUP_RESTORE.md)
- [Noyau Linux amont](UPSTREAM_LINUX.md) · [performance](PERFORMANCE.md) · [accès distant](REMOTE_ACCESS.md)

### Bureau et applications

- [GNOME](GNOME.md) · [Nautilus](NAUTILUS.md) · [Ptyxis](PTYXIS.md) · [Bash](HOST_BASH_UX.md)
- [Applications GTK4](GTK4_APPLICATIONS.md) · [AppImage](APPIMAGE.md) · [codecs](MULTIMEDIA_CODECS.md) · [diagnostic des couleurs](DISPLAY_COLOR_DIAGNOSTIC.md)
- [Gaming](GAMING.md)

### Virtualisation

- [Démarrage KVM](KVM_QUICKSTART.md) · [architecture KVM](VIRTUALIZATION.md) · [commandes avancées](KVM_QUICKSTART.md)
- [Profils VM](VIRTUALIZATION.md#profil-rocky-devops) · [réseau `devops-nat`](KVM_NETWORK.md) · [fichiers des VM](KVM_QUICKSTART.md)
- [Rocky DevOps : provisioning](VIRTUALIZATION.md#provisioning) · [état attendu](VIRTUALIZATION.md)

### Dépannage

Commencer par l'état réel avec `./control.sh status` et `./control.sh doctor all`, puis :

- [Dépannage](TROUBLESHOOTING.md) · [journaux et incidents](LOGS_ET_INCIDENTS.md)
- [Matériel et noyau](RUNBOOK_GOLDEN_HARDWARE.md) · [KVM](KVM_QUICKSTART.md#dépannage) · [données `/data` et Gaming](RUNBOOK_PERSISTENT_DATA_GAMING.md)

Ne jamais désactiver SELinux, firewalld ou un garde-fou pour faire disparaître une erreur.

### Développement

- [CI et validation](CI_VALIDATION.md) · [laboratoire Fedora/GNOME](FEDORA_GNOME_CI_LAB.md) · [feuille de route](ROADMAP_FEDORA45_2026.md)

### Historique

L'installation neuve ne passe pas par Fedora 44. [Fedora 44 historique](HISTORICAL_FEDORA44.md) · [mise à niveau facultative 44 → 45](UPGRADE_FEDORA_45.md) · [comptes rendus passés](history/README.md)
