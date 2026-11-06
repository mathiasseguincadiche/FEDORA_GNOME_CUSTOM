# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — liens, ancres, commandes `./control.sh` et chemins relus par `tests/test_docs_integrity.py` — matériel : non vérifié

Un dépôt qui décrit, installe et vérifie un poste **Fedora 45 Workstation / GNOME 51** : la même Fedora, sur le même matériel, reconstruite à l'identique et vérifiée par des contrôles reproductibles.

**Le problème que ce dépôt règle.** Une installation faite à la main ne survit pas à une réinstallation : chaque réglage, chaque logiciel et chaque correctif sont à retrouver, sans savoir si le résultat est le même. Ici, tout vit dans un dépôt Git — chaque réglage est versionné, expliqué, testé et rejouable.

**Le contexte.** Projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche), pour son propre PC ([Le poste cible](#le-poste-cible)), et comme terrain d'apprentissage des pratiques DevOps : configuration déclarative, tests de comportement, intégration continue et preuves.

**État réel en une ligne :** le logiciel est vérifié par la CI à chaque commit ; le PC n'est pas encore qualifié — le Live USB, l'installation et la Gate 3 restent à faire sur le matériel ([État réel](#état-réel)).

## Le parcours du poste, étape par étape

Tout passe par `./control.sh`, et l'ordre a un sens : **observer le PC (Live USB), essayer à blanc (dry-run), qualifier le matériel, puis installer, configurer, sauvegarder — et savoir restaurer**.

1. **Live USB — tester le PC avant d'installer** : `./control.sh validate live plan` puis `./control.sh validate live run`. La preuve porte `PREINSTALL_ONLY` : aucun paquet installé, aucun SSD touché. → [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md)
2. **Dry-run — voir le plan sans rien écrire** : `./install.sh --dry-run`. Le plan complet s'affiche, avec une preuve liée au commit. → [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours)
3. **Qualification — certifier le matériel avant toute mutation** : `./control.sh cert baseline-status` puis `./control.sh cert baseline-certify`. La baseline matérielle qualifie le PC (identités, SSD, affichage) avant l'APPLY. → [qualification](docs/QUALIFICATION.md)
4. **Install — appliquer réellement** : le gate exige machine approuvée, dépôt propre, dry-run réussi du même commit et sauvegarde pré-APPLY vérifiée (`./control.sh install backup`) ; puis `./control.sh install apply`, uniquement sur le PC physique. → [parcours d'installation](docs/INSTALLATION_GUIDE.md#le-parcours)
5. **Configurer — et vérifier** : les modules (système, bureau GNOME, gaming, KVM, réseau…) s'appliquent pendant l'APPLY ; `./control.sh doctor all` relit ensuite tout le poste en lecture seule. → [architecture](docs/ARCHITECTURE.md), [centre de contrôle](docs/CONTROL_CENTER.md)
6. **Backup — sauvegarder au quotidien** : `./control.sh backup now` (un timer quotidien existe aussi). → [sauvegardes et restauration](docs/BACKUP_RESTORE.md)
7. **Restore — restaurer si besoin** : `./control.sh backup restore [snapshot]`, d'abord dans un dossier d'essai. → [sauvegardes et restauration](docs/BACKUP_RESTORE.md)

**Puis la Gate 3** (`./control.sh validate gate3 status`) conclut le parcours : seule elle établit le statut « Golden runtime-certified ».

**Trois niveaux à ne jamais confondre** : une CI verte prouve le logiciel testé ; le Live (`PREINSTALL_ONLY`) n'observe que le PC avant installation ; seule la Gate 3 qualifie le système installé.

## Démarrer sans matériel

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py    # vérifier le dépôt
./install.sh --dry-run                     # le plan d'installation, à blanc
./control.sh                               # ouvrir le centre de contrôle
```

## Le centre de contrôle

`./control.sh` est la façade unique : sans argument, menu interactif ; `./control.sh help` liste toutes les commandes sans rien exécuter. Les domaines : `status`, `install`, `update`, `backup`, `doctor`, `kernel`, `kvm`, `remote`, `perf`, `cert`, `logs`, `validate`. La liste complète des commandes, qui fait foi : le [centre de contrôle](docs/CONTROL_CENTER.md). Rien ne s'applique sans essai à blanc, sauvegarde vérifiée et confirmation explicite, et uniquement sur le PC physique. Les réglages propres au poste : `config/local.conf`.

## Le poste cible

| Composant | Modèle | Rôle dans le projet |
|---|---|---|
| Processeur | AMD Ryzen 7 7700 (8 cœurs / 16 threads) | profils d'énergie, essais de stabilité |
| Carte mère | MSI MAG B850M Mortar WiFi | identité contrôlée, version du BIOS relevée |
| Mémoire | 48 Go DDR5-6000 (2 × 24 Go) | essais de stabilité pendant la baseline |
| Carte graphique | Intel Arc B580 Challenger 12 Go | réservée à l'hôte, pilote `xe` et Mesa de Fedora |
| Stockage | 2 × Crucial T705 1 To (PCIe 5.0) | système Btrfs sur le premier, `/data` persistant en EXT4 sur le second |
| Sauvegarde | SSD externe Kingston XS1000 | dépôt Borg externe |
| Écran | ASUS ROG Strix 27" QD-OLED, 1440p 240 Hz | affichage Wayland, soin de l'OLED |
| Réseau | Wi-Fi 7 Qualcomm + Realtek 5 GbE | identités et pilotes contrôlés |

Le détail complet et les contrôles associés : [architecture — le matériel cible](docs/ARCHITECTURE.md#le-matériel-cible).

## La documentation, selon le besoin

| Je veux… | Lire |
|---|---|
| Comprendre le projet | [notions clés](docs/CONCEPTS.md), [architecture](docs/ARCHITECTURE.md), [glossaire](docs/GLOSSARY.md), [décisions (ADR)](docs/adr/README.md) |
| Installer et prouver | [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md), [guide d'installation](docs/INSTALLATION_GUIDE.md), [qualification](docs/QUALIFICATION.md) |
| Utiliser le poste au quotidien | [centre de contrôle](docs/CONTROL_CENTER.md), [GNOME](docs/GNOME.md), [Gaming](docs/GAMING.md), [KVM](docs/KVM_QUICKSTART.md), [sauvegardes](docs/BACKUP_RESTORE.md), [dépannage](docs/TROUBLESHOOTING.md) |
| Suivre le projet | [CI et validation](docs/CI_VALIDATION.md), [feuille de route](docs/ROADMAP.md), [historique des versions](CHANGELOG.md) |
| Tout parcourir | le [portail de la documentation](docs/README.md) liste les 72 guides |

## État réel

| Élément | Avancement | Contrôle |
|---|---|---|
| Configuration, scripts, modules, diagnostics et tests | Réalisé | ce dépôt ; `python3 -B tests/test_docs_integrity.py` |
| CI : contrats, tests de comportement, laboratoires en VM | Vérifié le 2026-11-04 au commit `0007d97` — run `Tests` [41880009717](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions/runs/41880009717), succès | [CI et validation](docs/CI_VALIDATION.md) ; préversion [v0.24.1-rc.1](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases/tag/v0.24.1-rc.1) |
| Profil Fedora 45 : média final signé, RPM GNOME 51 stables | Vérifié le 2026-11-04 | [fiche Fedora 45](docs/FEDORA45_PRIMARY.md) |
| Contrôle Live USB, installation et Gate 3 sur le PC | Non vérifié | à faire sur le matériel : [qualification](docs/QUALIFICATION.md) |

**Une CI verte ne certifie pas le PC.** Seule la Gate 3, exécutée sur la machine installée, peut établir le statut « Golden runtime-certified ». Les versions publiées sont listées dans les [releases](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases) ; les prochaines étapes, dans la [feuille de route](docs/ROADMAP.md).

## Contribuer et licence

Les changements passent par pull request, avec les tests adaptés à leur portée ([consignes de contribution](CONTRIBUTING.md)), et sont fusionnés par le propriétaire. Licence : [Apache License 2.0](LICENSE) ; version courante : [`VERSION`](VERSION).
