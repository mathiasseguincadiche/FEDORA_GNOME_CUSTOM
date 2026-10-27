# Fedora Golden Workstation

Une configuration versionnée de **Fedora 45 Workstation avec GNOME 51**, pour un PC consacré au développement, au gaming et aux machines virtuelles.

[![Tests](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/workflows/tests.yml)
[![Licence Apache 2.0](https://img.shields.io/badge/licence-Apache%202.0-blue.svg)](LICENSE)

Le projet rassemble les réglages, les logiciels et les procédures nécessaires pour retrouver le même environnement après une installation neuve. Un point d’entrée permet de préparer l’installation, entretenir le poste, sauvegarder les données et lancer les diagnostics : **`./control.sh`**.

![Maquette du bureau GNOME cible](docs/assets/desktop-preview.svg)

*Maquette illustrative, pas une capture réelle. Les captures du poste seront ajoutées après sa qualification matérielle.*

## Ce que prépare le projet

- **Un bureau GNOME soigné** : Wayland, dock, tuilage, applications natives et réglages cohérents.
- **Un poste de travail polyvalent** : outils de développement, applications quotidiennes, Steam et environnement KVM.
- **Des données persistantes** sur un second SSD : documents, projets, projets IA dans `/data/IA/Openclaw` et stockage des VM.
- **Une maintenance documentée** : mises à jour, sauvegardes Borg, restauration et diagnostics par domaine.
- **Une configuration vérifiable** : plan consultable avant application, tests automatisés et qualification sur le matériel cible.

La configuration vise **Ryzen 7 7700 · Intel Arc B580 · 48 Gio de RAM · deux Crucial T705**. Les caractéristiques complètes et l’organisation de `/data` figurent dans le [guide d’installation](docs/INSTALLATION_GUIDE.md).

## État de la cible

**Fedora 45 / GNOME 51 est la cible d’installation neuve.** Le profil de production reste `pending` jusqu’à la qualification du média final signé et des composants nécessaires. Les conditions et l’état de promotion sont centralisés dans [la fiche Fedora 45](docs/FEDORA45_PRIMARY.md).

Les tests logiciels et la qualification du PC sont suivis séparément. La réussite des workflows GitHub ne certifie pas encore le fonctionnement du poste physique.

## Commencer

Pour préparer l’installation, lire d’abord le [contrôle du média Live](docs/FEDORA45_LIVE_PREFLIGHT.md), puis suivre le [guide d’installation neuve](docs/INSTALLATION_GUIDE.md).

Depuis la session Live Fedora 45, consulter puis exécuter les contrôles du PC :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
./control.sh validate live plan
./control.sh validate live run
```

Le guide détaille le parcours complet :

**Live USB → installation Fedora → configuration définitive → dry-run final → sauvegarde vérifiée → APPLY → redémarrage → qualification matérielle Gate 3.**

Pour l’usage quotidien, ouvrir le centre de contrôle :

```bash
./control.sh
```

## Documentation

| Besoin | Point de départ |
|---|---|
| Installer Fedora sur ce PC | [Installation](docs/INSTALLATION_GUIDE.md) |
| Utiliser et entretenir le poste | [Centre de contrôle](docs/CONTROL_CENTER.md) |
| Sauvegarder ou restaurer ses données | [Sauvegardes et restauration](docs/BACKUP_RESTORE.md) |
| Découvrir le bureau et le gaming | [GNOME](docs/GNOME.md) · [Gaming](docs/GAMING.md) |
| Utiliser les machines virtuelles | [Démarrage KVM](docs/KVM_QUICKSTART.md) |
| Résoudre un problème | [Dépannage](docs/TROUBLESHOOTING.md) |

La [documentation complète](docs/README.md) donne accès aux guides spécialisés, à l’[architecture](docs/ARCHITECTURE_PEDAGOGIQUE.md), aux décisions techniques et aux procédures de qualification.

## Contribuer

Les changements sont proposés par pull request, avec les vérifications adaptées à leur portée. Voir les [consignes de contribution](CONTRIBUTING.md) et l’[historique des versions](CHANGELOG.md).

## Licence

[Apache License 2.0](LICENSE) · [Version du projet](VERSION).
