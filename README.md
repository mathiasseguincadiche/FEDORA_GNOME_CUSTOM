# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — parcours relu contre le guide d'installation et les moteurs ; liens, ancres et commandes contrôlés par `tests/test_docs_integrity.py` — matériel : non vérifié

Un dépôt qui décrit, installe et vérifie un poste **Fedora 45 Workstation / GNOME 51** : la même Fedora, sur le même matériel, reconstruite à l'identique et vérifiée par des contrôles reproductibles.

**Le problème que ce dépôt règle.** Une installation faite à la main ne survit pas à une réinstallation : chaque réglage, chaque logiciel et chaque correctif sont à retrouver, sans savoir si le résultat est le même. Ici, tout vit dans un dépôt Git — chaque réglage est versionné, expliqué, testé et rejouable.

**Le contexte.** Projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche), pour son propre PC ([Le poste cible](#le-poste-cible)), et comme terrain d'apprentissage des pratiques DevOps : configuration déclarative, tests de comportement, intégration continue et preuves.

**Trois engagements.** **Reproductibilité recherchée** : le dépôt définit la configuration du poste et permet un essai à blanc avant l'APPLY. **Preuves limitées à leur portée** : la CI teste le logiciel ; l'état réel distingue ce qui est vérifié de ce qui ne l'est pas. **APPLY protégé** : l'application complète des modules exige le PC physique, une baseline, un dry-run du même état, une sauvegarde pré-APPLY vérifiée et une confirmation. Les opérations courantes possèdent leurs propres préconditions.

**État réel en une ligne :** le logiciel est vérifié par la CI à chaque commit ; le PC n'est pas encore qualifié — Live USB, installation et Gate 3 restent à faire sur le matériel ([État réel](#état-réel)).

## Le parcours du poste

```text
Live USB → installer Fedora → préparer /data → baseline → dry-run → sauvegarde → APPLY → vérifier → Gate 3
```

L'installation graphique de Fedora précède la configuration du projet. Ensuite, `./control.sh` orchestre les contrôles et les opérations, selon le [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours) qui fait foi pour l'ordre exact. Chaque étape distingue ce qu'elle prouve de ce qu'elle ne prouve pas.

### 1. Live USB — tester le PC avant d'installer

Depuis la clé Live, le poste est observé sans installer de paquet ni modifier les deux SSD. Le contrôle peut produire des preuves temporaires ; leur export écrit sur le support externe choisi.

```bash
./control.sh validate live plan
./control.sh validate live run
./control.sh validate export live /chemin/support-externe
```

**Prouve :** le matériel répond au contrat (affichage, stockage, réseau, KVM) ; la preuve porte `PREINSTALL_ONLY` et est liée au commit. **Ne prouve pas :** que le système installé fonctionnera — c'est le rôle de la Gate 3. → [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md)

### 2. Installer Fedora — avant de configurer le poste

Après le contrôle Live et l'export des preuves, installer **Fedora 45 Workstation sur le T705 système** avec l'installateur graphique. Ne pas formater le second T705 réservé à `/data`. Après le premier démarrage sur le SSD, cloner le dépôt **au même commit**, importer la preuve Live, puis préparer les outils et le montage `/data`.

**Prouve :** le système Fedora démarre et la preuve Live a été importée pour le même état. **Ne prouve pas :** la bonne application des modules ni la certification matérielle. → [installation et premier démarrage](docs/INSTALLATION_GUIDE.md#2-contrôler-le-pc-en-live-puis-installer-fedora)

### 3. Baseline — qualifier le matériel avant APPLY

Sur **Fedora installé**, après les prérequis et l'enrôlement des identités décrits dans le guide :

```bash
./control.sh cert baseline-status
./control.sh cert baseline-certify
```

**Prouve :** la baseline matérielle (identités, SSD, affichage, veille) est conforme aux critères et certifiée avant APPLY. **Ne prouve pas :** le comportement après application ; un changement de matériel rend la preuve caduque (`STALE`). → [qualification](docs/QUALIFICATION.md)

### 4. Dry-run — voir le plan sans appliquer les changements

```bash
./install.sh --dry-run
```

**Prouve :** le plan complet des modules (ordre, portée), avec une preuve écrite liée au commit et à la configuration. **Ne prouve pas :** qu'une application réelle réussira — d'où la sauvegarde et les protections de l'étape suivante. → [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours)

### 5. APPLY — sauvegarder puis appliquer les modules

> [!CAUTION]
> Point de non-retour : `install apply` fait converger le système vers le dépôt. Le gate exige au préalable une sauvegarde pré-APPLY vérifiée et un dry-run réussi du même commit.

```bash
./control.sh install backup
./control.sh install apply
```

**Prouve :** le système converge vers le dépôt, sur le PC physique uniquement. **Ne prouve pas :** la certification — seule la Gate 3 la délivre. → [parcours d'installation](docs/INSTALLATION_GUIDE.md#le-parcours)

### 6. Vérifier — examiner la configuration appliquée

Les modules (système, bureau GNOME, gaming, KVM, réseau…) ont été appliqués par l'APPLY ; le poste se relit en lecture seule :

```bash
./control.sh status
./control.sh doctor all
```

**Prouve :** l'état courant du poste (version, noyau, sauvegarde, certification). **Ne prouve pas :** la santé matérielle — les doctors lisent, ils ne réparent pas. → [architecture](docs/ARCHITECTURE.md), [centre de contrôle](docs/CONTROL_CENTER.md)

### 7. Backup — sauvegarder au quotidien

```bash
./control.sh backup now
./control.sh backup check
```

**Prouve :** une archive Borg vérifiée (`borg check --verify-data`) sur support externe. **Ne prouve pas :** qu'une restauration fonctionnera — d'où l'essai de restauration. → [sauvegardes](docs/BACKUP_RESTORE.md)

### 8. Restore — savoir restaurer si besoin

```bash
./control.sh backup restore latest
```

Toujours d'abord dans un dossier d'essai, jamais directement sur les données. → [sauvegardes et restauration](docs/BACKUP_RESTORE.md)

**La Gate 3** est la qualification finale du système installé. Consulter son état avec `./control.sh validate gate3 status` et suivre les essais prescrits par le [guide de qualification](docs/QUALIFICATION.md) : consulter un statut n'établit pas, à lui seul, la certification « Golden runtime-certified ».

**Trois niveaux à ne jamais confondre :** une CI verte prouve le logiciel testé ; le Live (`PREINSTALL_ONLY`) n'observe que le PC avant installation ; seule la Gate 3 qualifie le système installé.

## Démarrer sans matériel

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py    # vérifier liens, ancres, guides et routes
./install.sh --dry-run                     # plan à blanc ; peut refuser hors PC cible
./control.sh                               # ouvrir le centre de contrôle
```

## Le centre de contrôle

`./control.sh` est la façade unique : sans argument, menu interactif ; `./control.sh help` liste toutes les commandes sans rien exécuter. La liste complète des commandes, qui fait foi : le [centre de contrôle](docs/CONTROL_CENTER.md).

| Domaine | Exemples | Rôle |
|---|---|---|
| `status` | `./control.sh status` | tableau de bord, lecture seule |
| `install` | `./control.sh install dry-run`, `./control.sh install apply` | dry-run non mutant, APPLY protégé |
| `validate` | `./control.sh validate live run`, `./control.sh validate gate3 status` | preuve Live USB, Gate 3 |
| `cert` | `./control.sh cert baseline-certify` | baseline et certification |
| `backup` | `./control.sh backup now`, `./control.sh backup restore` | sauvegardes et restauration |
| `doctor` | `./control.sh doctor all` | diagnostics, lecture seule |
| `update` | `./control.sh update all` | mises à jour, sauvegarde d'abord |
| `kernel` | `./control.sh kernel status` | noyau N / N-1, secours Fedora signé |
| `kvm` | `./control.sh kvm status` | VM et garde réseau fermé par défaut |
| `remote` | `./control.sh remote status` | SSH, Tailscale, Wake-on-LAN |
| `perf` | `./control.sh perf status` | profils d'énergie mesurés |
| `logs` | `./control.sh logs tail` | journaux et rétention |

L'**APPLY** exige baseline, essai à blanc, sauvegarde pré-APPLY vérifiée et confirmation sur le PC physique. Les actions d'exploitation, comme le changement de profil TuneD, ont d'autres gardes : leur nature est indiquée dans le [centre de contrôle](docs/CONTROL_CENTER.md#une-façade-des-moteurs-spécialisés). Les réglages propres au poste : `config/local.conf`.

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
| Tout parcourir | le [portail de la documentation](docs/README.md) oriente vers les guides, les décisions et les archives |

## État réel

| Élément | Avancement | Contrôle |
|---|---|---|
| Configuration, scripts, modules, diagnostics et tests | Réalisé | ce dépôt ; `python3 -B tests/test_docs_integrity.py` |
| CI : contrats, tests de comportement, laboratoires en VM | Preuve historique : run `Tests` réussi le 2026-11-04 au commit `0007d97` ; **le commit courant doit être vérifié séparément** | [Actions sur `main`](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/actions?query=branch%3Amain), [CI et validation](docs/CI_VALIDATION.md) ; préversion [v0.24.1-rc.1](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases/tag/v0.24.1-rc.1) |
| Profil Fedora 45 : média final signé, RPM GNOME 51 stables | Vérifié le 2026-11-04 | [fiche Fedora 45](docs/FEDORA45_PRIMARY.md) |
| Contrôle Live USB, installation et Gate 3 sur le PC | Non vérifié | à faire sur le matériel : [qualification](docs/QUALIFICATION.md) |

**Une CI verte ne certifie pas le PC.** Seule la Gate 3, exécutée sur la machine installée, peut établir le statut « Golden runtime-certified ». Les versions publiées sont listées dans les [releases](https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM/releases) ; les prochaines étapes, dans la [feuille de route](docs/ROADMAP.md).

## Contribuer et licence

Les changements passent par pull request, avec les tests adaptés à leur portée ([consignes de contribution](CONTRIBUTING.md)), et sont fusionnés par le propriétaire. Licence : [Apache License 2.0](LICENSE) ; version courante : [`VERSION`](VERSION).
