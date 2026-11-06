# Documentation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — parcours de lecture et renvois relus contre les guides ; liens et ancres contrôlés par `tests/test_docs_integrity.py` — matériel : non vérifié

Bienvenue dans la documentation de **Fedora Golden Workstation**. Inutile de tout lire avant de commencer : choisir d'abord son objectif, puis suivre les guides dans l'ordre indiqué.

Le projet cible **Fedora 45 Workstation / GNOME 51** sur un matériel précis. Le profil d'installation est `ready` ([fiche Fedora 45](FEDORA45_PRIMARY.md)), mais **cela ne veut pas dire que le PC physique est déjà qualifié**. Les preuves disponibles et les étapes encore à réaliser figurent dans l'[état réel](../README.md#état-réel).

## Choisir son parcours

### Je découvre le projet

Commencer par les [notions clés](CONCEPTS.md) : pourquoi les opérations s'arrêtent en cas de doute, ce qu'est une preuve valide et pourquoi une sauvegarde doit être restaurable. Lire ensuite la [vue d'ensemble](ARCHITECTURE.md) pour comprendre les composants et leurs relations. Le [glossaire](GLOSSARY.md) définit les termes rencontrés au fil de la lecture.

### Je prépare une installation sur le vrai PC

Le [guide d'installation](INSTALLATION_GUIDE.md) donne l'ordre officiel. Le passage par le [Live USB](FEDORA45_LIVE_PREFLIGHT.md) permet d'observer le matériel avant d'effacer un disque. **Après l'export des résultats de la Gate 2, on s'arrête pour la revue et l'accord du propriétaire.** Une fois Fedora installé et configuré, la [Gate 3](QUALIFICATION.md) qualifie le système réel.

Pour un premier essai, ne sauter ni la vérification de l'ISO ni la sauvegarde pré-APPLY. Les [points de non-retour](INSTALLATION_GUIDE.md#points-de-non-retour) expliquent pourquoi.

### J'utilise ou je dépanne le poste

Le [centre de contrôle](CONTROL_CENTER.md) explique `./control.sh` et les effets de chaque domaine de commandes. Pour protéger les données, suivre le guide [sauvegarde et restauration](BACKUP_RESTORE.md). En cas de panne, le [dépannage](TROUBLESHOOTING.md) aide à partir du symptôme plutôt que d'essayer des modifications au hasard.

## Par besoin

| Je veux… | Lire |
|---|---|
| Comprendre le projet | [Notions clés](CONCEPTS.md), [vision et architecture](ARCHITECTURE.md), [glossaire](GLOSSARY.md), [décisions (ADR)](adr/README.md) |
| Savoir où en est le projet | [État réel](../README.md#état-réel), [feuille de route](ROADMAP.md) |
| Installer ce PC | [Contrôle Live](FEDORA45_LIVE_PREFLIGHT.md), [décision avant installation](FEDORA45_LIVE_PREFLIGHT.md#6-décider-avant-toute-installation), puis [installation](INSTALLATION_GUIDE.md) |
| Utiliser et entretenir le poste | [Centre de contrôle](CONTROL_CENTER.md), [maintenance](DESKTOP_LIFECYCLE.md), [sauvegardes](BACKUP_RESTORE.md) |
| Le bureau, les jeux, les VM | [GNOME](GNOME.md), [Gaming](GAMING.md), [démarrage KVM](KVM_QUICKSTART.md) |
| Résoudre un problème | [Dépannage](TROUBLESHOOTING.md) |
| Prouver que la machine est prête | [Qualification](QUALIFICATION.md) et sa [fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) |
| Contribuer | [Guide du contributeur](../CONTRIBUTING.md), [CI](CI_VALIDATION.md), [décisions](adr/README.md) |

**La règle de lecture :** le [guide d'installation](INSTALLATION_GUIDE.md#le-parcours) fait foi pour l'ordre réel des opérations ; la [qualification](QUALIFICATION.md) pour les critères des preuves ; le [centre de contrôle](CONTROL_CENTER.md) pour les commandes. Les pages de présentation résument et orientent, elles ne remplacent pas ces références.

La CI ne certifie pas le matériel. Le Live USB ne déverrouille jamais `install.sh --apply`. Une décision humaine favorable après Gate 2 n'élimine pas les gardes techniques de l'APPLY.

## Tous les guides

### Projet et règles

- [Vision et architecture](ARCHITECTURE.md) : composants, matériel cible, données et règles de sécurité.
- [Notions clés](CONCEPTS.md) : comprendre les décisions avant de mémoriser les commandes.
- [Glossaire](GLOSSARY.md) et [décisions d'architecture (ADR)](adr/README.md) : vocabulaire et raisons des choix.
- [Politique de sécurité de l'hôte](HOST_SECURITY_POLICY.md), [provenance des logiciels](SUPPLY_CHAIN.md), [inventaire logiciel](SOFTWARE_INVENTORY.md) : contrôles et sources des composants.

### Installation et qualification

- [Fiche Fedora 45](FEDORA45_PRIMARY.md) : identité et authenticité du média retenu.
- [Contrôle Live USB](FEDORA45_LIVE_PREFLIGHT.md) : préinstallation, collecte de preuves, décision humaine.
- [Guide d'installation](INSTALLATION_GUIDE.md) : parcours officiel, sauvegarde pré-APPLY et configuration.
- [Qualification](QUALIFICATION.md) et [fiche physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) : vérifier le poste installé (Gate 3).
- [Reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md) : essais de récupération hors du poste de production.

### Usage quotidien

- [Centre de contrôle](CONTROL_CENTER.md) : commandes disponibles, préconditions et effets.
- [Maintenance du poste](DESKTOP_LIFECYCLE.md) et [noyau Linux amont](UPSTREAM_LINUX.md) : garder un système exploitable et récupérable.
- [Sauvegardes et restauration](BACKUP_RESTORE.md) : politique Borg, contrôles, restitution des fichiers.
- [Performance](PERFORMANCE.md) et [accès distant](REMOTE_ACCESS.md) : comportement du poste et accès réseau.

### Bureau et applications

- [GNOME](GNOME.md), [Nautilus](NAUTILUS.md), [Ptyxis](PTYXIS.md) et [Bash](HOST_BASH_UX.md) : comprendre et personnaliser le quotidien.
- [Applications GTK4](GTK4_APPLICATIONS.md), [AppImage](APPIMAGE.md), [codecs](MULTIMEDIA_CODECS.md) : installer, intégrer et contrôler les applications.
- [Diagnostic des couleurs](DISPLAY_COLOR_DIAGNOSTIC.md) et [Gaming](GAMING.md) : affichage, multimédia et jeux.

### Virtualisation

- [KVM au quotidien](KVM_QUICKSTART.md) : créer et utiliser une VM Rocky DevOps.
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
