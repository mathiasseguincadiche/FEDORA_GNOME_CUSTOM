# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — parcours relu contre les scripts et les guides ; validation sur PC à réaliser — matériel : non vérifié

**Un poste Fedora que l'on peut comprendre, reconstruire et vérifier.**

Fedora Golden Workstation rassemble les scripts, les configurations et les procédures pour transformer une installation de **Fedora 45 Workstation / GNOME 51** en environnement personnel de travail, de développement et de virtualisation.

Le but est simple : après une réinstallation, retrouver un poste cohérent sans dépendre d'une suite de manipulations faites de mémoire. Les choix sont versionnés dans Git ; les commandes sont contrôlées ; chaque opération sensible possède ses conditions d'arrêt.

> [!IMPORTANT]
> **État réel : les contrôles logiciels sont disponibles en CI ; les essais sur le PC restent à réaliser.** Le profil Fedora est `ready`, mais cela ne signifie ni que le Live USB a été validé ni que le poste est certifié. [Consulter les preuves et leurs limites](#état-réel).

## Par où commencer ?

| Votre objectif | Le bon point d'entrée |
|---|---|
| **Découvrir** le projet et ses choix | [Notions clés](docs/CONCEPTS.md) · [Architecture](docs/ARCHITECTURE.md) |
| **Tester** le PC sans toucher aux disques | [Préinstallation en Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) |
| **Installer** et configurer Fedora après validation | [Guide d'installation](docs/INSTALLATION_GUIDE.md) |
| **Entretenir** le poste ou récupérer des données | [Centre de contrôle](docs/CONTROL_CENTER.md) · [Sauvegarde et restauration](docs/BACKUP_RESTORE.md) |
| **Comprendre un échec** | [Dépannage](docs/TROUBLESHOOTING.md) · [Glossaire](docs/GLOSSARY.md) |

Le [portail documentaire](docs/README.md) réunit tous les guides, y compris ceux sur GNOME, la virtualisation KVM, les applications et la CI.

## Comment le poste est organisé

![Architecture du poste cible : Fedora et ses usages, SSD système Btrfs, SSD de données ext4, sauvegarde Borg externe](docs/assets/diagrams/architecture-poste.svg)

[Ouvrir la source Draw.io](docs/assets/diagrams/architecture-poste.drawio) · [Lire l'architecture détaillée](docs/ARCHITECTURE.md)

**Deux SSD, deux responsabilités.** Le premier Crucial T705 accueille Fedora et le système de fichiers Btrfs. Le second accueille `/data` en ext4 : il est destiné à conserver les données lors d'une réinstallation du système. La séparation des disques n'est pas une sauvegarde : une panne ou une erreur peut toujours détruire les données du second SSD.

**La sauvegarde est un troisième espace.** Borg utilise un SSD externe Kingston XS1000. Les dossiers Documents, Projets et IA figurent parmi les données protégées ; les ISO, les jeux et les disques des machines virtuelles ne sont pas automatiquement inclus. Le [guide Borg](docs/BACKUP_RESTORE.md) précise également les dossiers personnels et les réglages sauvegardés, les exclusions et la restauration en zone isolée.

L'environnement vise notamment le bureau GNOME, les outils DevOps, le jeu vidéo et la virtualisation KVM. Les choix de sécurité et de matériel propres à cette machine sont présentés dans [l'architecture](docs/ARCHITECTURE.md).

## De la clé USB au poste qualifié

Le parcours comporte **trois Gates aux rôles distincts**. Leur séparation est définie dans le code et ne doit pas être modifiée pour simplifier la présentation.

| Étape | Ce qui se passe | Ce qui autorise la suite |
|---|---|---|
| **Gate 1 — CI** | Les contrôles logiciels s'exécutent sur le commit exact. | Les résultats attendus sont conformes ; ils ne certifient pas le matériel. |
| **Gate 2 — Live USB** | Le PC démarre sur « Try Fedora », les contrôles de préinstallation sont effectués sans installer Fedora, puis les preuves sont exportées. | **Revue des résultats et décision humaine explicite** avant toute installation. |
| **Installation protégée** | Fedora est installé sur le SSD système identifié ; la preuve Live est importée. Viennent ensuite baseline, dry-run, sauvegarde Borg pré-APPLY vérifiée, APPLY et redémarrage. | Les préconditions et protections de chaque opération doivent être satisfaites. |
| **Gate 3 — système installé** | Les diagnostics et les essais physiques qualifient le bureau, les périphériques, les applications, les sauvegardes et les usages réels. | Certification uniquement si les preuves requises sont valides. |

> [!CAUTION]
> **Après Gate 2, on s'arrête.** Un `GO` calculé par les scripts ne donne jamais, à lui seul, l'autorisation d'installer ni d'effacer un disque. Le propriétaire examine le compte rendu et décide explicitement de poursuivre ou non. [Comprendre la décision GO / NO-GO](docs/FEDORA45_LIVE_PREFLIGHT.md#6-décider-avant-toute-installation).

Le [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours) fait foi pour l'ordre des commandes et les points de non-retour. La [qualification](docs/QUALIFICATION.md) décrit ce que prouvent — et ne prouvent pas — les résultats de chaque Gate.

## Premiers pas sans modifier le PC

Depuis un poste disposant de Git et de Python 3, ces commandes téléchargent le dépôt, vérifient les liens et les parcours documentaires, puis affichent l'aide :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py  # lecture et contrôles documentaires
./control.sh help                       # consultation des commandes disponibles
```

**Pour tester le vrai PC**, démarrer depuis la clé USB Fedora et choisir « Try Fedora ». Après vérification des prérequis décrits dans le [guide Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md), se placer sur le commit contrôlé en CI et utiliser :

```bash
./control.sh validate live plan                                      # voir les 16 points à observer
./control.sh validate live run                                       # effectuer les contrôles Live
./control.sh validate live status                                    # lire le résultat calculé
./control.sh validate export live /chemin/support-externe/preinstallation # exporter les preuves hors des SSD internes
```

Ces commandes ne lancent aucune installation. Le chemin d'export désigne un **support externe accessible en écriture**. Les observations humaines, les conditions d'export et les modalités d'analyse sont détaillées dans le guide Live : ne pas improviser cette procédure depuis le seul README.

### Pourquoi existe-t-il un centre de contrôle ?

`./control.sh` est la porte d'entrée des opérations. Il aide à trouver la bonne commande, mais ne remplace pas les moteurs spécialisés ni leurs garde-fous :

- **Observer** : `./control.sh status`, `./control.sh doctor all` et `./control.sh logs tail`.
- **Préparer** : `./control.sh install dry-run`, seulement dans le contexte et après les prérequis du PC cible.
- **Protéger** : `./control.sh backup now` ou `./control.sh backup restore`.
- **Qualifier** : `./control.sh validate live status` ou `./control.sh validate gate3 status`, selon l'environnement.

Un *dry-run* simule la configuration ; **APPLY** exécute réellement les changements. L'APPLY n'est jamais une commande de découverte : il exige notamment une baseline certifiée, un dry-run à jour, une sauvegarde pré-APPLY vérifiée et une confirmation physique. [Voir toutes les commandes, leurs effets et leurs conditions](docs/CONTROL_CENTER.md).

## État réel

| Domaine | État et limite de la preuve | Référence |
|---|---|---|
| Scripts, configurations et contrats logiciels | Contrôles automatisés disponibles ; leur succès vaut **pour un commit et un environnement précis**. | [GitHub Actions sur `main`](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions?query=branch%3Amain) · [CI](docs/CI_VALIDATION.md) |
| Profil et média Fedora 45 / GNOME 51 | Profil `ready` et média final authentifié ; **aucune certification matérielle implicite**. | [Fiche Fedora 45](docs/FEDORA45_PRIMARY.md) |
| Gate 2, installation réelle, Gate 3 | **À exécuter sur le PC physique** ; résultats non encore établis. | [Qualification](docs/QUALIFICATION.md) · [Feuille de route](docs/ROADMAP.md) |

Une CI verte ne certifie pas la workstation. Seule une Gate 3 réussie sur le système installé et ses identités matérielles courantes peut établir le statut « Golden runtime-certified ». Une modification du matériel, du code ou de la configuration peut rendre des preuves antérieures périmées.

## Pour approfondir

- **Environnement** : [GNOME](docs/GNOME.md), [applications et jeu](docs/GAMING.md), [KVM et Rocky Linux](docs/KVM_QUICKSTART.md).
- **Maintenance et diagnostics** : [sauvegardes](docs/BACKUP_RESTORE.md), [dépannage](docs/TROUBLESHOOTING.md), [CI et lecture des jobs](docs/CI_VALIDATION.md).
- **Décisions et évolution** : [ADR](docs/adr/README.md), [feuille de route](docs/ROADMAP.md), [historique des changements](CHANGELOG.md), [versions publiées](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases).

Projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche), également consacré à l'apprentissage de l'exploitation et de l'automatisation d'infrastructures. Les contributions passent par [pull request](CONTRIBUTING.md). Licence : [Apache 2.0](LICENSE) · [Version courante](VERSION).
