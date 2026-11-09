# Fedora Golden Workstation

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — premiers pas relus contre `control.sh`, les guides et les limites des Gates — matériel : non vérifié

**Préparer, personnaliser et entretenir une workstation Fedora depuis un centre de contrôle.**

Fedora 45 Workstation · GNOME 51 · Automatisation · Qualification · Sauvegarde et restauration

## Pourquoi ce projet ?

Réinstaller un PC ne devrait pas obliger à retrouver de mémoire chaque commande, application et réglage. Ce dépôt rassemble les configurations, les scripts et les contrôles nécessaires pour **reconstruire un environnement de travail connu**, vérifier son fonctionnement et le maintenir dans le temps.

Le projet applique aussi une démarche DevOps au poste personnel : code versionné, contrôles automatisés, opérations encadrées, preuves de validation et procédures de reprise. **« Golden » désigne une configuration de référence à reproduire et à qualifier**, pas une image ISO personnalisée ni une certification déjà obtenue.

**Vous découvrez Fedora ou l'automatisation ?** Commencez par les [notions clés](docs/CONCEPTS.md), puis revenez au parcours ci-dessous. **Vous connaissez déjà Linux ?** Le [centre de contrôle](docs/CONTROL_CENTER.md) donne le détail des commandes et de leurs effets. Dans les deux cas, le [guide d'installation](docs/INSTALLATION_GUIDE.md) reste la référence avant toute modification du PC.

## Le centre de contrôle : votre point d'entrée

Le cœur de l'expérience est **`./control.sh`**. Il regroupe l'accès aux opérations de préparation, d'installation, de mise à jour, de diagnostic, de sauvegarde, de restauration et de qualification. Chaque action est ensuite confiée à un script spécialisé, avec ses propres vérifications de sécurité.

![Maquette illustrative de Fedora 45 sous GNOME 51 : bureau personnalisé, Dash to Dock et terminal affichant le centre de contrôle](docs/assets/illustrations/centre-controle-fedora45-gnome51.webp)

*Maquette de l'expérience visée **après configuration** : elle montre comment ouvrir le centre de contrôle dans un terminal. Ce n'est ni une capture du PC réel ni une preuve de réussite. La session Live USB utilisée avant installation ne dispose pas encore de cette personnalisation.*

### Premier contact : explorer avant d'agir

Depuis un terminal Linux avec Git disponible :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
./control.sh help  # découvrir les commandes, sans lancer d'opération
./control.sh       # ouvrir le menu interactif, sans sélectionner d'action
```

Le clonage crée une copie du dépôt sur le disque. La commande `help` se limite à présenter les choix ; ouvrir le menu ne lance pas d'installation. **En revanche, choisir une opération dans ce menu peut modifier le système.** Pour découvrir le projet sans intervenir sur Fedora, arrêtez-vous à `help` et lisez le guide correspondant.

**Avant un essai réel**, utiliser le commit dont les contrôles CI ont été vérifiés, puis suivre les prérequis de la procédure concernée. Le centre de contrôle automatise les opérations prévues par le dépôt ; **le choix des disques, l'installation initiale de Fedora et certaines confirmations physiques restent manuels**.

Pour comprendre chaque option : **[guide complet du centre de contrôle](docs/CONTROL_CENTER.md)**. Pour voir les composants qu'il appelle : [schéma technique](docs/assets/diagrams/centre-de-controle.svg) · [source Draw.io](docs/assets/diagrams/centre-de-controle.drawio).

## De la première vérification au poste qualifié

Suivez les étapes dans l'ordre. Le README indique **où commencer et ce que chaque étape permet de vérifier** ; les commandes, prérequis, captures de preuves et solutions en cas d'échec sont détaillés dans les procédures liées.

| Étape | Ce que vous faites | Procédure à suivre |
| --- | --- | --- |
| **Gate 1 — contrôles logiciels** | Vérifier les tests GitHub Actions du **commit exact** choisi. Une CI verte ne teste pas votre PC. | [Comprendre et vérifier la CI](docs/CI_VALIDATION.md) |
| **Gate 2 — avant installation** | Démarrer sur la clé **Live USB**, observer le matériel et les fonctions essentielles, puis exporter un rapport. | [Préinstallation : tests Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) |
| **Décision humaine** | Examiner le rapport Gate 2 et donner ou refuser l'autorisation d'installer. **Un résultat `GO` ne suffit pas.** | [Interpréter les résultats et décider](docs/FEDORA45_LIVE_PREFLIGHT.md#6-décider-avant-toute-installation) |
| **Installation et configuration** | Installer Fedora sur le disque explicitement choisi ; importer le rapport, préparer le système, effectuer le *dry-run*, vérifier la sauvegarde puis lancer l'**APPLY protégé**. | [Installation pas à pas](docs/INSTALLATION_GUIDE.md) |
| **Gate 3 — après installation** | Tester le vrai système, son bureau, ses périphériques, ses sauvegardes et les fonctions du profil avant toute certification. | [Qualification du système installé](docs/QUALIFICATION.md) |

> [!CAUTION]
> **Point d'arrêt impératif :** la Gate 2 n'autorise jamais, à elle seule, l'effacement d'un disque. L'installation demande un accord humain explicite. L'APPLY exige ensuite ses propres préconditions, notamment une sauvegarde pré-APPLY vérifiée. **Ne contournez pas un refus de sécurité.**

**À retenir :** Gate 1 = *le code* ; Gate 2 = *le PC avant installation* ; Gate 3 = *le PC réellement installé et configuré*. Ces validations ne se remplacent pas. Une certification n'est valable que pour l'état effectivement testé.

## Après l'installation : utiliser et entretenir le poste

Le même centre de contrôle accompagne l'exploitation quotidienne. Cliquez sur la procédure adaptée avant de lancer une opération :

| Votre besoin | Où trouver les étapes détaillées |
| --- | --- |
| **Mettre Fedora et ses composants à jour** | [Mises à jour et maintenance](docs/CONTROL_CENTER.md#mises-à-jour) · [cycle de vie du poste](docs/DESKTOP_LIFECYCLE.md) |
| **Créer et vérifier une sauvegarde Borg** | [Sauvegarder et contrôler les archives](docs/BACKUP_RESTORE.md) |
| **Restaurer des fichiers ou préparer une reprise** | [Restauration sécurisée](docs/BACKUP_RESTORE.md#restaurer) · [reprise après sinistre](docs/BACKUP_RESTORE.md#reprendre-après-une-perte-totale) |
| **Diagnostiquer un échec et consulter les journaux** | [Guide de dépannage](docs/TROUBLESHOOTING.md) · [commandes de diagnostic](docs/CONTROL_CENTER.md) |
| **Vérifier ou renouveler la qualification** | [Critères de qualification](docs/QUALIFICATION.md) · [fiche de tests physiques](docs/PHYSICAL_QUALIFICATION_CHECKLIST.md) |

Les sauvegardes ont des **périmètres et des exclusions** ; les restaurations commencent dans une zone isolée, sans écraser automatiquement les fichiers en place. Les procédures expliquent ces précautions et les vérifications à réaliser.

## État réel

Le profil Fedora 45 / GNOME 51 est déclaré `ready`, et le dépôt dispose de contrôles logiciels en CI. **Cela ne signifie pas que le poste physique est installé ou certifié.** La Gate 2 sur clé USB, l'installation et l'APPLY réels, puis la Gate 3 restent à effectuer et à prouver sur le matériel cible.

Consulter les [résultats GitHub Actions](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions?query=branch%3Amain), la [feuille de route](docs/ROADMAP.md) et les [règles de qualification](docs/QUALIFICATION.md) pour connaître la portée exacte de chaque validation.

## Comprendre le projet en profondeur

- [Portail de toute la documentation](docs/README.md) : choisir un guide selon son objectif.
- [Architecture et décisions techniques](docs/ARCHITECTURE.md) · [décisions ADR](docs/adr/README.md) : comprendre les composants et leurs choix.
- [Notions clés](docs/CONCEPTS.md) · [glossaire](docs/GLOSSARY.md) : apprendre progressivement, même en découvrant les outils.
- [GNOME et applications](docs/GNOME.md) · [laboratoire KVM/Rocky](docs/KVM_QUICKSTART.md) : explorer les fonctionnalités du poste.

---

Projet personnel de [Mathias SEGUIN-CADICHE](https://github.com/mathiasseguincadiche) consacré à l'automatisation, à la fiabilité et à l'exploitation d'un poste Linux. [Contribuer](CONTRIBUTING.md) · [Historique](CHANGELOG.md) · [Licence Apache 2.0](LICENSE) · [Version du projet](VERSION)
