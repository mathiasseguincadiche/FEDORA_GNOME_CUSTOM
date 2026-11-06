# Fedora Golden Workstation

[![Tests](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/workflows/tests.yml)
[![Licence Apache 2.0](https://img.shields.io/badge/licence-Apache%202.0-blue.svg)](LICENSE)

Un dépôt qui décrit, installe et vérifie un poste **Fedora 45 Workstation / GNOME 51** : la même Fedora, sur le même matériel, reconstruite à l'identique et vérifiée par des contrôles reproductibles.

Projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche), pour son propre PC (Ryzen 7 7700, Intel Arc B580, 48 Gio de RAM, deux SSD Crucial T705, consacré au développement, au jeu vidéo et aux machines virtuelles) et comme terrain d'apprentissage des pratiques DevOps : configuration déclarative, tests de comportement, intégration continue et preuves.

## Démarrage rapide

Sans matériel, rien ne s'écrit :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py    # vérifier le dépôt
./install.sh --dry-run                     # le plan d'installation, à blanc
./control.sh                               # ouvrir le centre de contrôle
```

Sur le PC cible : le [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) d'abord, puis le [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours), puis la [qualification Gate 3](docs/QUALIFICATION.md).

## Le centre de contrôle

Tester, installer, configurer, diagnostiquer, entretenir, sauvegarder, prouver : chaque interaction avec le poste passe par `./control.sh`, le point d'entrée unique. Sans argument, il ouvre le menu interactif ; `./control.sh help` liste toutes les commandes sans rien exécuter.

Exemple de session, sorties illustratives, pas des résultats observés :

```text
$ ./control.sh
  menu interactif : installation, mises à jour, noyau, KVM, sauvegarde, diagnostics, certification

$ ./control.sh status
  tableau de bord : version, noyau N / N-1, /data, sauvegarde Borg, certification

$ ./control.sh doctor all
  tous les diagnostics, en lecture seule

$ ./control.sh install dry-run
  le plan d'installation complet, sans rien écrire
```

Rien ne s'applique sans essai à blanc, sauvegarde vérifiée et confirmation explicite, et uniquement sur le PC physique. La liste des commandes, qui fait foi : le [centre de contrôle](docs/CONTROL_CENTER.md) ; les réglages propres au poste : `config/local.conf`.

## Documentation

- **Comprendre** : [notions clés](docs/CONCEPTS.md), [architecture](docs/ARCHITECTURE.md), [glossaire](docs/GLOSSARY.md), [décisions (ADR)](docs/adr/README.md)
- **Installer et prouver** : [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md), [guide d'installation](docs/INSTALLATION_GUIDE.md), [qualification](docs/QUALIFICATION.md)
- **Utiliser au quotidien** : [centre de contrôle](docs/CONTROL_CENTER.md), [GNOME](docs/GNOME.md), [Gaming](docs/GAMING.md), [KVM](docs/KVM_QUICKSTART.md), [sauvegardes](docs/BACKUP_RESTORE.md), [dépannage](docs/TROUBLESHOOTING.md)
- **Suivre le projet** : [CI et validation](docs/CI_VALIDATION.md), [feuille de route](docs/ROADMAP.md), [historique des versions](CHANGELOG.md)
- **Tous les guides** : le [portail de la documentation](docs/README.md)

## État réel

La CI vérifie le logiciel à chaque pull request et chaque commit ; le PC, lui, n'est pas encore qualifié : le contrôle Live USB, l'installation et la Gate 3 restent à faire sur le matériel, et seule la Gate 3 peut établir le statut « Golden runtime-certified ». Preuves et détails : [CI](docs/CI_VALIDATION.md), [releases](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases).

## Contribuer et licence

Les changements passent par pull request, avec les tests adaptés à leur portée ([consignes de contribution](CONTRIBUTING.md)), et sont fusionnés par le propriétaire. Licence : [Apache License 2.0](LICENSE) ; version courante : [`VERSION`](VERSION).
