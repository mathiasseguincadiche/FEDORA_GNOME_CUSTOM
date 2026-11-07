# Documentation — Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — parcours de lecture et renvois relus contre les guides ; liens et ancres contrôlés par `tests/test_docs_integrity.py` — matériel : non vérifié

**Une bibliothèque technique que l'on peut parcourir à son rythme.** Ici, les guides ne sont pas rangés selon l'ordre des fichiers du dépôt, mais selon ce que l'on cherche à comprendre ou à réaliser.

Vous découvrez Fedora et ses outils ? Commencez par les notions et la vue d'ensemble. Vous devez intervenir sur le PC ? Suivez la procédure correspondant à votre objectif et vérifiez ses préconditions avant d'exécuter une commande.

Le projet cible **Fedora 45 Workstation / GNOME 51** sur un matériel précis. Le profil d'installation est `ready` ([fiche Fedora 45](FEDORA45_PRIMARY.md)), mais **cela ne veut pas dire que le PC physique est déjà qualifié**. Les preuves disponibles et les étapes encore à réaliser figurent dans l'[état réel](../README.md#état-réel).

## Choisir son parcours

| Si vous souhaitez… | Commencer ici | Puis approfondir |
|---|---|---|
| **Comprendre** le projet sans prérequis | [Notions clés](CONCEPTS.md) | [Architecture](ARCHITECTURE.md) et [glossaire](GLOSSARY.md) |
| **Préparer** une première installation | [Essais Live USB — Gate 2](FEDORA45_LIVE_PREFLIGHT.md) | [Installation pas à pas](INSTALLATION_GUIDE.md) et [points de non-retour](INSTALLATION_GUIDE.md#points-de-non-retour) |
| **Utiliser** et maintenir Fedora | [Centre de contrôle](CONTROL_CENTER.md) | [Maintenance](DESKTOP_LIFECYCLE.md) et [Borg](BACKUP_RESTORE.md) |
| **Diagnostiquer** un problème | [Dépannage](TROUBLESHOOTING.md) | [CI](CI_VALIDATION.md) et guides du domaine concerné |
| **Qualifier** une machine installée | [Qualification](QUALIFICATION.md) | [Fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) et [état réel](../README.md#état-réel) |
| **Contribuer** au dépôt | [Guide du contributeur](../CONTRIBUTING.md) | [Décisions (ADR)](adr/README.md) |

> [!IMPORTANT]
> **Les références ne sont pas interchangeables.** Le [guide d'installation](INSTALLATION_GUIDE.md#le-parcours) fixe l'ordre des opérations, la [qualification](QUALIFICATION.md) définit les preuves, et le [centre de contrôle](CONTROL_CENTER.md) décrit les commandes. Après la Gate 2 en Live USB, l'installation exige une **revue et un accord humain**, même si le script calcule `GO`. La Gate 3 n'intervient qu'après l'installation sur le PC réel.

## Tous les guides

### Projet et règles

- [Vision et architecture](ARCHITECTURE.md) : composants, matériel cible, données et règles de sécurité.
- [Notions clés](CONCEPTS.md) : comprendre les décisions avant de mémoriser les commandes.
- [Glossaire](GLOSSARY.md) et [décisions d'architecture (ADR)](adr/README.md) : vocabulaire et raisons des choix.
- [Politique de sécurité de l'hôte](HOST_SECURITY_POLICY.md), [provenance des logiciels](SUPPLY_CHAIN.md), [inventaire logiciel](SOFTWARE_INVENTORY.md) : contrôles et sources des composants.

### Installation et qualification

- [Fiche Fedora 45](FEDORA45_PRIMARY.md) : identité et authenticité du média retenu.
- [Contrôle Live USB](FEDORA45_LIVE_PREFLIGHT.md) : préinstallation, collecte de preuves, décision humaine.
- [Guide d'installation](INSTALLATION_GUIDE.md) : parcours officiel, sauvegarde pré-APPLY et configuration ; [préparer ou réutiliser `/data`](DATA_DISK_PREPARATION.md) au moment indiqué.
- [Qualification](QUALIFICATION.md) et [fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) : vérifier le poste installé (Gate 3).
- [Reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md) : essais de récupération hors du poste de production.

### Usage quotidien

- [Centre de contrôle](CONTROL_CENTER.md) : commandes disponibles, préconditions et effets.
- [Fiabilité opérateur](OPERATOR_RELIABILITY.md) : lire les logs, comprendre les résultats, distinguer les actions rejouables et suivre une mise à jour.
- [Couverture des mises à jour](UPDATE_COVERAGE.md) : noyau, pilotes, codecs, logiciels, Steam/Proton, Flatpak, extensions, AppImage et firmware ; procédure de contrôle et finalisation.
- [Maintenance du poste](DESKTOP_LIFECYCLE.md) et [noyau Linux amont](UPSTREAM_LINUX.md) : garder un système exploitable et récupérable.
- [Sauvegardes et restauration](BACKUP_RESTORE.md) : politique Borg, contrôles, restitution des fichiers.
- [Performance](PERFORMANCE.md) et [accès distant](REMOTE_ACCESS.md) : comportement du poste et accès réseau.

### Bureau et applications

- [GNOME](GNOME.md), [Nautilus](NAUTILUS.md), [Ptyxis](PTYXIS.md) et [Bash](HOST_BASH_UX.md) : comprendre et personnaliser le quotidien.
- [Applications GTK4](GTK4_APPLICATIONS.md), [AppImage](APPIMAGE.md), [codecs](MULTIMEDIA_CODECS.md) : installer, intégrer et contrôler les applications.
- [Diagnostic des couleurs](DISPLAY_COLOR_DIAGNOSTIC.md) et [Gaming](GAMING.md) : affichage, multimédia et jeux.

### Virtualisation

- [KVM au quotidien](KVM_QUICKSTART.md) : créer et utiliser une VM Rocky DevOps ; [export et reprise manuels](KVM_EXPORT_RESTORE.md) avant toute modification importante.
- [Référence virtualisation](VIRTUALIZATION.md) : architecture, profils et préparation des machines virtuelles.
- [Réseau `devops-nat`](KVM_NETWORK.md) : isolation, politique de filtrage et diagnostic.

### Dépannage

Commencer par l'état réel avec `./control.sh status` et `./control.sh doctor all`, puis :

- [Dépannage](TROUBLESHOOTING.md) · [journaux et incidents](TROUBLESHOOTING.md#journaux-et-incidents)
- [Matériel et noyau](TROUBLESHOOTING.md#carte-mère-cpu-mémoire-et-stockage) · [KVM](KVM_QUICKSTART.md#dépannage) · [données `/data` et Gaming](TROUBLESHOOTING.md#données-data-et-gaming)

Ne jamais désactiver SELinux, firewalld ou un garde-fou pour faire disparaître une erreur.

### Développement

- [CI et validation](CI_VALIDATION.md) : lire les jobs, les preuves et les échecs d'intégration.
- [Laboratoire Fedora/GNOME](FEDORA_GNOME_CI_LAB.md) : comprendre ce que les VM de test exercent réellement.
- [Feuille de route](ROADMAP.md) : distinguer les éléments terminés de ceux encore à qualifier.

### Historique

L'installation neuve ne passe pas par Fedora 44. [Fedora 44 historique](history/HISTORICAL_FEDORA44.md) · [mise à niveau facultative 44 → 45](UPGRADE_FEDORA_45.md) · [comptes rendus passés](history/README.md)
