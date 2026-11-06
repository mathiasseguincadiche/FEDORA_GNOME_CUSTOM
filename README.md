# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — parcours et commandes relus contre les scripts de validation, d'installation et de sauvegarde ; contrôles documentaires et contrats des Gates exécutés localement — matériel : non vérifié

**Préparer, configurer et maintenir un poste Fedora avec des opérations traçables.** Ce dépôt réunit les scripts, configurations, diagnostics et procédures d'un poste personnel sous **Fedora 45 Workstation / GNOME 51**. Il vise une installation reproductible sur le matériel cible, sans prétendre qu'un test logiciel certifie déjà ce matériel.

## Pourquoi ce projet ?

Après une réinstallation classique, il faut retrouver les logiciels, reconstituer les réglages et espérer n'avoir oublié aucune étape. Deux installations faites manuellement peuvent donc aboutir à deux postes différents, difficiles à dépanner ou à restaurer.

Avec Fedora Golden Workstation, les choix importants sont conservés dans Git : chacun peut être relu, expliqué, corrigé et contrôlé. L'installation de Fedora reste une opération distincte ; le projet prépare ensuite le poste, applique sa configuration et accompagne son exploitation.

Ce projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche) sert aussi à apprendre les pratiques d'exploitation et d'automatisation d'infrastructure : **scripts Bash, contrôle des changements, validation, CI/CD, sauvegardes Borg et virtualisation KVM**.

**Où en est-on ?** Le code dispose de tests automatisés, mais le parcours Live USB et la certification du PC réel restent **non vérifiés**. Voir l'[état réel et ses preuves](#état-réel).

## Ce que le dépôt apporte

| Fonction | Ce qu'elle permet concrètement |
|---|---|
| Configuration versionnée | Retrouver les choix et les modules qui composent le poste. |
| Précontrôles | Vérifier les prérequis et arrêter les opérations si les conditions de sécurité manquent. |
| Exécution à blanc | Examiner le plan des modifications avant de les appliquer. |
| Installation protégée | Exiger une baseline, un dry-run cohérent, une sauvegarde pré-APPLY vérifiée et une confirmation humaine. |
| Diagnostics | Observer l'état du système, du bureau GNOME, du réseau, du stockage et des composants matériels. |
| Sauvegarde et restauration | Protéger des données sélectionnées avec Borg et restaurer d'abord dans un dossier d'essai. |
| Qualification | Distinguer les preuves logicielles, les observations Live USB et les résultats du système installé. |

![Vue de l'architecture du poste Fedora : système, stockage, composants et services](docs/assets/diagrams/architecture-poste.svg)

Schéma de présentation du poste ; [source modifiable draw.io](docs/assets/diagrams/architecture-poste.drawio) et [explications techniques de l'architecture](docs/ARCHITECTURE.md).

## Le parcours du poste

Ce parcours sépare **ce qui doit être observé avant l'installation** de **ce qui ne peut être vérifié qu'après**. Le [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours) fait foi pour l'ordre et les commandes détaillées.

| Quand ? | Étape | Pourquoi elle compte | Guide |
|---|---|---|---|
| Avant le Live | **1. Préparer** | Vérifier l'ISO signée, la clé USB, le commit Git et les supports externes. | [Installation](docs/INSTALLATION_GUIDE.md) |
| Depuis « Try Fedora » | **2. Gate 2 — Live USB** | Observer les 16 points prévus, enregistrer les résultats et exporter la preuve `PREINSTALL_ONLY`. | [Contrôle Live](docs/FEDORA45_LIVE_PREFLIGHT.md) |
| **Avant toute installation** | **3. Revue et décision humaine** | Examiner les résultats, les échecs et les points non testés ; le propriétaire donne ou refuse son accord. | [Décision GO / NO-GO](docs/FEDORA45_LIVE_PREFLIGHT.md#6-décider-avant-toute-installation) |
| Après accord | **4. Installer Fedora** | Installer sur le T705 système seulement, puis importer la preuve Live au même commit. | [Installation](docs/INSTALLATION_GUIDE.md#2-contrôler-le-pc-en-live-puis-installer-fedora) |
| Sur Fedora installé | **5. Préparer et mesurer** | Configurer `/data`, certifier la baseline matérielle et lancer le dry-run. | [Installation](docs/INSTALLATION_GUIDE.md#le-parcours) |
| Avant l'APPLY | **6. Sauvegarder** | Créer et vérifier un point de retour Borg avant toute convergence du système. | [Sauvegarde pré-APPLY](docs/BACKUP_RESTORE.md#sauvegarde-pré-apply) |
| Après les prérequis | **7. Configurer** | Appliquer les modules, redémarrer et contrôler le système obtenu. | [Installation](docs/INSTALLATION_GUIDE.md#le-parcours) |
| Sur le poste configuré | **8. Gate 3 — certification finale** | Exécuter les essais physiques et fonctionnels du système installé, puis certifier si les critères sont remplis. | [Qualification](docs/QUALIFICATION.md#4-gate-3--système-installé) |
| En exploitation | **9. Protéger et récupérer** | Vérifier les sauvegardes régulières installées par l'APPLY et éprouver la restauration dans un dossier d'essai. | [Sauvegardes et restauration](docs/BACKUP_RESTORE.md) |

> [!IMPORTANT]
> **Entre la Gate 2 et l'installation, le parcours s'arrête volontairement.** Un `GO` calculé par le script confirme uniquement les observations obligatoires de préinstallation. Il n'autorise pas, à lui seul, l'effacement du disque. Conserver le compte rendu, l'analyser et obtenir la décision explicite du propriétaire avant de lancer l'installateur Fedora.

### Première manipulation : tester sans installer

Sur le **PC cible démarré depuis la clé USB**, dans le dépôt positionné sur le commit audité :

```bash
./control.sh validate live plan                         # lire les points à contrôler
./control.sh validate live run                          # effectuer les observations
./control.sh validate live status                       # consulter l'état de la preuve
./control.sh validate export live /chemin/support-externe # sauvegarder la preuve hors de la session Live
```

Les commandes Live ne préparent pas le disque à l'installation et ne certifient pas GNOME installé. Le [guide Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) explique les prérequis, les réponses humaines, l'export et l'analyse des résultats. Le support d'export doit être un volume externe distinct des deux SSD internes.

### Après autorisation : configurer sans brûler les étapes

L'installation graphique précède les scripts de configuration. Une fois Fedora démarré sur le SSD, les opérations de baseline, de dry-run et de sauvegarde pré-APPLY sont **des conditions de sécurité**, pas des étapes facultatives. L'APPLY refuse de s'exécuter si ses preuves ne correspondent plus à l'état courant du système.

Après l'APPLY, la **Gate 3** vérifie notamment le bureau réel, les périphériques, le réseau, la veille, les sauvegardes et la virtualisation. La commande `./control.sh validate gate3 status` consulte un état : elle ne remplace pas `./control.sh validate gate3 certify` ni les essais qui la précèdent.

**À retenir :** Gate 1 = logiciel en CI ; Gate 2 = compatibilité observée en Live USB ; Gate 3 = qualification du poste installé. Ces trois preuves ne sont pas interchangeables.

## Explorer sans toucher au PC cible

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py    # vérifier liens, ancres, guides et routes
./control.sh help                          # voir les commandes disponibles
./install.sh --dry-run                     # plan à blanc ; peut refuser hors PC cible
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

## Trouver le bon guide

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
