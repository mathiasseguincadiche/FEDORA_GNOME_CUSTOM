# Fedora Golden Workstation

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — liens, ancres, commandes `./control.sh` et chemins relus par `tests/test_docs_integrity.py` — matériel : non vérifié

Un dépôt qui décrit, installe et vérifie un poste **Fedora 45 Workstation / GNOME 51** : la même Fedora, sur le même matériel, reconstruite à l'identique et vérifiée par des contrôles reproductibles.

**Le problème que ce dépôt règle.** Une installation faite à la main ne survit pas à une réinstallation : chaque réglage, chaque logiciel et chaque correctif sont à retrouver, sans savoir si le résultat est le même. Ici, tout vit dans un dépôt Git — chaque réglage est versionné, expliqué, testé et rejouable.

**Le contexte.** Projet personnel de [@mathiasseguincadiche](https://github.com/mathiasseguincadiche), pour son propre PC (voir [Le poste cible](#le-poste-cible)), et comme terrain d'apprentissage des pratiques DevOps : configuration déclarative, tests de comportement, intégration continue et preuves.

**État réel en une ligne :** le logiciel est vérifié par la CI à chaque commit ; le PC n'est pas encore qualifié — le contrôle Live USB, l'installation et la Gate 3 restent à faire sur le matériel ([État réel](#état-réel)).

## Démarrer : le centre de contrôle

Chaque interaction avec le poste passe par `./control.sh`, le point d'entrée unique. Sans argument, il ouvre le menu interactif ; `./control.sh help` liste toutes les commandes sans rien exécuter.

| Je veux… | Commande | Effet |
|---|---|---|
| Voir l'état du poste | `./control.sh status` | tableau de bord, lecture seule |
| Diagnostiquer | `./control.sh doctor all` | tous les diagnostics, lecture seule |
| Voir le plan d'installation | `./control.sh install dry-run` | plan complet, sans rien écrire |
| Installer réellement | `./control.sh install apply` | mutation protégée, PC physique uniquement |
| Mettre à jour le système | `./control.sh update all` | paquets, flatpaks, firmware |
| Sauvegarder | `./control.sh backup now` | sauvegarde Borg vérifiée |
| Voir le noyau | `./control.sh kernel status` | N / N-1, secours Fedora signé |
| Voir les machines virtuelles | `./control.sh kvm status` | KVM et garde réseau fermé par défaut |
| Voir l'accès à distance | `./control.sh remote status` | SSH, Tailscale, Wake-on-LAN, Sunshine |
| Voir la certification | `./control.sh cert status` | baseline et Gate 3 |

La liste complète des commandes, qui fait foi : le [centre de contrôle](docs/CONTROL_CENTER.md). Rien ne s'applique sans essai à blanc, sauvegarde vérifiée et confirmation explicite, et uniquement sur le PC physique. Les réglages propres au poste : `config/local.conf`.

Sans matériel, rien ne s'écrit :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
python3 -B tests/test_docs_integrity.py    # vérifier le dépôt
./install.sh --dry-run                     # le plan d'installation, à blanc
./control.sh                               # ouvrir le centre de contrôle
```

Sur le PC cible : le [contrôle Live USB](docs/FEDORA45_LIVE_PREFLIGHT.md) d'abord, puis le [guide d'installation](docs/INSTALLATION_GUIDE.md#le-parcours), puis la [qualification Gate 3](docs/QUALIFICATION.md).

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
