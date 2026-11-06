# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — liens, ancres, commandes `./control.sh`, chemins et visuels relus par `tests/test_docs_integrity.py` — matériel : non vérifié

[![Tests](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/workflows/tests.yml)

<div align="center">

![Bannière du projet : titre, pile cible Fedora 45 Workstation et GNOME 51, fenêtre de la console control.sh et parcours du poste en cinq étapes](docs/assets/hero-banner.svg)

</div>

**72 pages** de documentation · **77 modules** d'installation · **16 domaines** de commandes — constatés sur `main` le 2026-11-06 par `tests/test_docs_integrity.py`.

Une installation faite à la main se perd : après une réinstallation, chaque réglage, chaque logiciel et chaque correctif sont à retrouver, sans savoir si le résultat est le même. Ici, tout vit dans un dépôt Git : chaque réglage est versionné, expliqué, testé et rejouable. Le dépôt décrit, installe et vérifie un poste **Fedora 45 Workstation / GNOME 51** : la même Fedora, sur le même matériel, reconstruite à l'identique et vérifiée par des contrôles reproductibles.

Projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche), pour son propre PC (Ryzen 7 7700, Intel Arc B580, 48 Gio de RAM, deux SSD Crucial T705, consacré au développement, au jeu vidéo et aux machines virtuelles), et comme terrain d'apprentissage des pratiques DevOps : configuration déclarative, tests de comportement, intégration continue et preuves.

**État réel en une ligne :** le logiciel est vérifié par la CI à chaque commit ; le PC n'est pas encore qualifié — le contrôle Live USB, l'installation et la Gate 3 restent à faire sur le matériel (voir [État réel](#état-réel)).

## Tout se pilote depuis la console

Tester, installer, configurer, diagnostiquer, entretenir, sauvegarder, prouver : chaque interaction avec le poste passe par `./control.sh`, le point d'entrée unique. Sans argument, il ouvre le menu interactif ; `./control.sh help` liste toutes les commandes sans rien exécuter.

<div align="center">

![Maquette de l'interface de contrôle en thème sombre : barre de titre, menu des domaines, tableau de bord à six cartes reprenant l'état réel, rappel des garde-fous et ligne de commande](docs/assets/console-mockup.svg)

</div>

*Maquette illustrative, pas une capture réelle ; les statuts affichés reprennent l'[état réel](#état-réel) du projet.*

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

## Le poste en bref

<div align="center">

![Maquette du bureau GNOME cible : barre supérieure, dock à gauche, terminal et gestionnaire de fichiers côte à côte](docs/assets/desktop-preview.svg)

*Maquette illustrative, pas une capture réelle. Les captures du poste seront ajoutées après sa qualification matérielle.*

</div>

- **Système** : Fedora 45 Workstation · GNOME 51 sous Wayland ([architecture et matériel](docs/ARCHITECTURE.md#le-matériel-cible))
- **Usages** : développement, jeu vidéo, machines virtuelles KVM
- **Données** : un second SSD persistant monté sur `/data`, sauvegardé par Borg vers un support externe ([sauvegardes](docs/BACKUP_RESTORE.md))
- **Noyau** : Linux amont stable, avec un noyau Fedora signé en secours ([Linux amont](docs/UPSTREAM_LINUX.md))

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

## Documentation

- **Comprendre** : [notions clés](docs/CONCEPTS.md), [architecture](docs/ARCHITECTURE.md), [glossaire](docs/GLOSSARY.md), [décisions (ADR)](docs/adr/README.md)
- **Installer et prouver** : [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md), [guide d'installation](docs/INSTALLATION_GUIDE.md), [qualification](docs/QUALIFICATION.md)
- **Utiliser au quotidien** : [centre de contrôle](docs/CONTROL_CENTER.md), [GNOME](docs/GNOME.md), [Gaming](docs/GAMING.md), [KVM](docs/KVM_QUICKSTART.md), [sauvegardes](docs/BACKUP_RESTORE.md), [dépannage](docs/TROUBLESHOOTING.md)
- **Suivre le projet** : [CI et validation](docs/CI_VALIDATION.md), [feuille de route](docs/ROADMAP.md), [historique des versions](CHANGELOG.md)
- **Tous les guides** : le [portail de la documentation](docs/README.md)

## État réel

| Élément | Avancement | Contrôle |
|---|---|---|
| Configuration, scripts, modules, diagnostics et tests | Réalisé | ce dépôt ; `python3 -B tests/test_docs_integrity.py` |
| CI : contrats, tests de comportement, laboratoires en VM | Vérifié le 2026-11-04 au commit `0007d97` — run `Tests` [41880009717](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/runs/41880009717), succès | [CI et validation](docs/CI_VALIDATION.md) ; préversion [v0.24.1-rc.1](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases/tag/v0.24.1-rc.1) |
| Profil Fedora 45 : média final signé, RPM GNOME 51 stables | Vérifié le 2026-11-04 | [fiche Fedora 45](docs/FEDORA45_PRIMARY.md), relue contre `installer/fedora45-media.lock` |
| Contrôle Live USB, installation et Gate 3 sur le PC | Non vérifié | à faire sur le matériel : [qualification](docs/QUALIFICATION.md) |

**Une CI verte ne certifie pas le PC.** Seule la Gate 3, exécutée sur la machine installée, peut établir le statut « Golden runtime-certified ». Les versions publiées sont listées dans les [releases](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases) ; les prochaines étapes, dans la [feuille de route](docs/ROADMAP.md).

## Contribuer et licence

Les changements passent par pull request, avec les tests adaptés à leur portée ([consignes de contribution](CONTRIBUTING.md)), et sont fusionnés par le propriétaire. Licence : [Apache License 2.0](LICENSE) ; version courante : [`VERSION`](VERSION).
